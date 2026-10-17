<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SyncChange extends Model
{
    protected $primaryKey = 'sequence_id';
    public $timestamps = false;

    protected $fillable = [
        'user_id',
        'entity_type',
        'entity_id',
        'entity_version',
        'operation',
        'payload',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'sequence_id' => 'integer',
            'entity_version' => 'integer',
            'payload' => 'array',
            'created_at' => 'datetime',
        ];
    }
}
