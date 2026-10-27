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
            $user = User::create([
                'id' => User::deterministicIdForUsername($username),
                'username' => $username,
                'name' => $name,
                'email' => $email,
                'password' => Hash::make($password),
                'is_active' => true,
            ]);
        }

        $this->info("Akun pengguna '{$user->username}' ({$user->id}) berhasil disimpan.");
        return self::SUCCESS;
    }
}
