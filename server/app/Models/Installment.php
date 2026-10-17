<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Installment extends Model
{
    use HasUuids;

    protected $fillable = [
        'id',
        'user_id',
        'plan_id',
        'sequence_no',
        'due_date',
        'planned_amount',
        'status',
        'version',
    ];

    protected function casts(): array
    {
        return [
            'sequence_no' => 'integer',
            'due_date' => 'date:Y-m-d',
            'planned_amount' => 'integer',
            'version' => 'integer',
        ];
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(InstallmentPlan::class, 'plan_id');
    }

    public function payments(): HasMany
    {
        return $this->hasMany(InstallmentPayment::class, 'installment_id');
    }

    public function remainingAmount(): int
    {
        $paid = (int) $this->payments()->where('status', 'posted')->sum('amount');
        return max(0, (int) $this->planned_amount - $paid);
    }
}
