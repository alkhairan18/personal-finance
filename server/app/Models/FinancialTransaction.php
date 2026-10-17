<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class FinancialTransaction extends Model
{
    use HasUuids;

    protected $fillable = [
        'id',
        'user_id',
        'type',
        'amount_minor',
        'transaction_date',
        'category_id',
        'payment_method',
        'note',
        'source_type',
        'source_id',
        'status',
        'reverses_transaction_id',
    ];

    protected function casts(): array
    {
        return [
            'amount_minor' => 'integer',
            'transaction_date' => 'date:Y-m-d',
        ];
    }
}
