<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class InstallmentPlan extends Model
{
    use HasUuids;

    protected $fillable = [
        'id',
        'user_id',
        'title',
        'total_amount',
        'installment_count',
        'frequency',
        'start_date',
        'note',
        'status',
        'version',
        'archived_at',
    ];

    protected function casts(): array
    {
        return [
            'total_amount' => 'integer',
            'installment_count' => 'integer',
            'start_date' => 'date:Y-m-d',
            'version' => 'integer',
            'archived_at' => 'datetime',
        ];
    }

    public function installments(): HasMany
    {
        return $this->hasMany(Installment::class, 'plan_id')->orderBy('sequence_no');
    }
}
