<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Debt extends Model
{
    use HasUuids;

    protected $fillable = [
        'id',
        'user_id',
        'direction',
        'counterparty',
        'principal_amount',
        'start_date',
        'due_date',
        'note',
        'status',
        'version',
        'archived_at',
    ];

    protected function casts(): array
    {
        return [
            'principal_amount' => 'integer',
            'start_date' => 'date:Y-m-d',
            'due_date' => 'date:Y-m-d',
            'version' => 'integer',
            'archived_at' => 'datetime',
        ];
    }

    public function payments(): HasMany
    {
        return $this->hasMany(DebtPayment::class);
    }

    public function remainingAmount(): int
    {
        $paid = (int) $this->payments()->where('status', 'posted')->sum('amount');
        return max(0, (int) $this->principal_amount - $paid);
    }
}
