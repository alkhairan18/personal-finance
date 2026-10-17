<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class Category extends Model
{
    use HasUuids;

    protected $fillable = [
        'id',
        'user_id',
        'name',
        'type',
        'icon_key',
        'is_system',
        'version',
        'archived_at',
    ];

    protected function casts(): array
    {
        return [
            'is_system' => 'boolean',
            'version' => 'integer',
            'archived_at' => 'datetime',
        ];
    }
}
