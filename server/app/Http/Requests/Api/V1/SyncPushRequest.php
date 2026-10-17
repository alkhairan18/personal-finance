<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;

class SyncPushRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'device_id' => ['required', 'uuid'],
            'operations' => ['required', 'array', 'min:1', 'max:100'],
            'operations.*.operation_id' => ['required', 'uuid'],
            'operations.*.entity_type' => [
                'required',
                'string',
                'in:category,financial_transaction,debt,debt_payment,installment_plan,installment,installment_payment,wishlist',
            ],
            'operations.*.entity_id' => ['required', 'uuid'],
            'operations.*.action' => [
                'required',
                'string',
                'in:upsert,archive,record_debt_payment,record_installment_payment,reverse_transaction,reverse_debt_payment,reverse_installment_payment',
            ],
            'operations.*.base_version' => ['nullable', 'integer', 'min:1'],
            'operations.*.client_created_at' => ['nullable', 'string'],
            'operations.*.payload' => ['nullable', 'array'],
        ];
    }
}
