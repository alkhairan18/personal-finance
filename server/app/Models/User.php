<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, HasUuids, Notifiable;

    protected $fillable = [
        'id',
        'name',
        'username',
        'email',
        'password',
        'is_active',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_active' => 'boolean',
        ];
    }

    public function devices(): HasMany
    {
        return $this->hasMany(Device::class);
    }

    public static function deterministicIdForUsername(string $username): string
    {
        $clean = strtolower(trim($username));
        if ($clean === 'anzhel') {
            return '22222222-2222-4222-8222-000000000001';
        }
        if ($clean === 'wina') {
            return '22222222-2222-4222-8222-000000000002';
        }
        $hex = hash('sha256', 'pf-user-id-v1:' . $clean);
        return substr($hex, 0, 8) . '-'
            . substr($hex, 8, 4) . '-4'
            . substr($hex, 13, 3) . '-8'
            . substr($hex, 17, 3) . '-'
            . substr($hex, 20, 12);
    }
}
