<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class CreateFinanceUserCommand extends Command
{
    protected $signature = 'finance:create-user
                            {username : Unique username (e.g. anzhel or wina)}
                            {name : Display name}
                            {--password= : Initial password}
                            {--email= : Optional email address}';

    protected $description = 'Create or update an administrative Personal Finance user account (Anzhel or Wina)';

    public function handle(): int
    {
        $username = strtolower(trim((string) $this->argument('username')));
        $name = trim((string) $this->argument('name'));
        $password = (string) ($this->option('password') ?: $this->secret('Enter initial password'));
        $email = $this->option('email') ? trim((string) $this->option('email')) : null;

        if ($password === '') {
            $this->error('Password tidak boleh kosong.');
            return self::FAILURE;
        }

        $deterministicIds = [
            'anzhel' => '22222222-2222-4222-8222-000000000001',
            'wina' => '22222222-2222-4222-8222-000000000002',
        ];

        $existing = User::where('username', $username)->first();
        if ($existing) {
            $existing->update([
                'name' => $name,
                'email' => $email,
                'password' => Hash::make($password),
                'is_active' => true,
            ]);
            $user = $existing->fresh();
        } else {
            $attributes = [
                'username' => $username,
                'name' => $name,
                'email' => $email,
                'password' => Hash::make($password),
                'is_active' => true,
            ];
            if (isset($deterministicIds[$username])) {
                $attributes['id'] = $deterministicIds[$username];
            }
            $user = User::create($attributes);
        }

        $this->info("Akun pengguna '{$user->username}' ({$user->id}) berhasil disimpan.");
        return self::SUCCESS;
    }
}
