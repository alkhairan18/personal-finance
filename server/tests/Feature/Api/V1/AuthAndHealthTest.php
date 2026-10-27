<?php

namespace Tests\Feature\Api\V1;

use App\Models\Device;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class AuthAndHealthTest extends TestCase
{
    use RefreshDatabase;

    public function test_health_endpoint_returns_minimal_status(): void
    {
        $this->getJson('/api/v1/health')
            ->assertOk()
            ->assertExactJson(['data' => ['status' => 'ok']]);
    }

    public function test_artisan_command_creates_anzhel_and_wina_accounts_with_hashed_passwords(): void
    {
        $this->artisan('finance:create-user', [
            'username' => 'anzhel',
            'name' => 'Anzhel',
            '--password' => 'SecretPass123!',
        ])->assertExitCode(0);

        $this->artisan('finance:create-user', [
            'username' => 'wina',
            'name' => 'Wina',
            '--password' => 'WinaSecret123!',
        ])->assertExitCode(0);

        $user = User::where('username', 'anzhel')->firstOrFail();
        $wina = User::where('username', 'wina')->firstOrFail();
        $this->assertSame('22222222-2222-4222-8222-000000000001', $user->id);
        $this->assertSame('22222222-2222-4222-8222-000000000002', $wina->id);
        $this->assertNotSame('SecretPass123!', $user->password);
        $this->assertTrue(password_verify('SecretPass123!', $user->password));
    }

    public function test_login_endpoint_is_rate_limited_after_repeated_attempts(): void
    {
        for ($i = 0; $i < 10; $i++) {
            $this->postJson('/api/v1/auth/login', [
                'username' => 'anzhel',
                'password' => 'WrongPassword123!',
                'device_id' => (string) Str::uuid(),
                'device_name' => 'BruteForceBot',
            ]);
        }

        $this->postJson('/api/v1/auth/login', [
            'username' => 'anzhel',
            'password' => 'WrongPassword123!',
            'device_id' => (string) Str::uuid(),
            'device_name' => 'BruteForceBot',
        ])->assertStatus(429);
    }

    public function test_login_issues_token_and_binds_device_and_logout_revokes_token(): void
    {
        $user = User::factory()->create([
            'username' => 'anzhel',
            'name' => 'Anzhel',
            'password' => bcrypt('SecretPass123!'),
            'is_active' => true,
        ]);
        $deviceId = (string) Str::uuid();

        $login = $this->postJson('/api/v1/auth/login', [
            'username' => 'anzhel',
            'password' => 'SecretPass123!',
            'device_id' => $deviceId,
            'device_name' => 'Samsung S23 Anzhel',
        ])->assertOk();

        $token = $login->json('data.token');
        $this->assertNotEmpty($token);
        $this->assertSame($user->id, $login->json('data.user.id'));

        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.user.username', 'anzhel');

        $this->withToken($token)->postJson('/api/v1/auth/logout')
            ->assertOk();

        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertStatus(401)
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }

    public function test_revoked_device_cannot_access_protected_endpoints(): void
    {
        $user = User::factory()->create([
            'username' => 'wina',
            'name' => 'Wina',
            'password' => bcrypt('WinaPass123!'),
            'is_active' => true,
        ]);
        $deviceId = (string) Str::uuid();

        $login = $this->postJson('/api/v1/auth/login', [
            'username' => 'wina',
            'password' => 'WinaPass123!',
            'device_id' => $deviceId,
            'device_name' => 'Pixel Wina',
        ])->assertOk();

        $token = $login->json('data.token');
        Device::where('id', $deviceId)->update(['revoked_at' => now()]);

        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertStatus(401)
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }

    public function test_backup_finance_database_command_creates_json_snapshot(): void
    {
        $outputPath = storage_path('app/backups/test_backup_snapshot.json');
        @unlink($outputPath);

        $this->artisan('finance:backup-db', [
            '--output' => $outputPath,
        ])->assertExitCode(0);

        $this->assertFileExists($outputPath);
        $decoded = json_decode((string) file_get_contents($outputPath), true);
        $this->assertIsArray($decoded);
        $this->assertArrayHasKey('financial_transactions', $decoded['tables']);
        @unlink($outputPath);
    }

    public function test_any_new_user_can_register_via_api_and_get_deterministic_uuid_and_sanctum_token(): void
    {
        $deviceId = (string) Str::uuid();
        $res = $this->postJson('/api/v1/auth/register', [
            'name' => 'Budi Santoso',
            'username' => 'budi_santoso',
            'password' => 'PasswordKuat123!',
            'device_id' => $deviceId,
            'device_name' => 'Xiaomi 14 Budi',
        ])->assertCreated();

        $token = $res->json('data.token');
        $this->assertNotEmpty($token);
        $this->assertSame('budi_santoso', $res->json('data.user.username'));
        $this->assertSame('Budi Santoso', $res->json('data.user.name'));
        $this->assertSame(User::deterministicIdForUsername('budi_santoso'), $res->json('data.user.id'));

        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.user.username', 'budi_santoso');

        // Duplicate username should return 422
        $this->postJson('/api/v1/auth/register', [
            'name' => 'Budi Lain',
            'username' => 'budi_santoso',
            'password' => 'PasswordKuat123!',
            'device_id' => (string) Str::uuid(),
        ])->assertStatus(422);
    }
}
