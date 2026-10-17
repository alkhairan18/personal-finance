<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class Wishlist extends Model
{
    use HasUuids;

    protected $fillable = [
        'id',
        'user_id',
        'title',
        'target_price',
        'target_date',
        'priority',
        'category',
        'icon_key',
        'status',
        'note',
        'version',
        'archived_at',
    ];

    protected function casts(): array
    {
        return [
            'target_price' => 'integer',
            'target_date' => 'date:Y-m-d',
            'version' => 'integer',
            'archived_at' => 'datetime',
        ];
    }
}
