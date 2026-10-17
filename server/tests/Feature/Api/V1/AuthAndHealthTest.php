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

        $user = User::where('username', 'anzhel')->firstOrFail();
        $this->assertNotSame('SecretPass123!', $user->password);
        $this->assertTrue(password_verify('SecretPass123!', $user->password));
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
}
