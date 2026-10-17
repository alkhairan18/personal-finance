<?php

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Seeder;

class SystemCategorySeeder extends Seeder
{
    public const SYSTEM_CATEGORIES = [
        ['id' => '00000000-0000-4000-8000-000000000001', 'name' => 'Makan & Minum', 'type' => 'expense', 'icon_key' => 'fork-knife'],
        ['id' => '00000000-0000-4000-8000-000000000002', 'name' => 'Transportasi', 'type' => 'expense', 'icon_key' => 'gas-pump'],
        ['id' => '00000000-0000-4000-8000-000000000003', 'name' => 'Belanja Harian', 'type' => 'expense', 'icon_key' => 'shopping-bag'],
        ['id' => '00000000-0000-4000-8000-000000000004', 'name' => 'Tagihan & Utilitas', 'type' => 'expense', 'icon_key' => 'lightning'],
        ['id' => '00000000-0000-4000-8000-000000000005', 'name' => 'Kesehatan', 'type' => 'expense', 'icon_key' => 'first-aid-kit'],
        ['id' => '00000000-0000-4000-8000-000000000006', 'name' => 'Hiburan', 'type' => 'expense', 'icon_key' => 'film-slate'],
        ['id' => '00000000-0000-4000-8000-000000000007', 'name' => 'Cicilan & Kewajiban', 'type' => 'expense', 'icon_key' => 'calendar-check'],
        ['id' => '00000000-0000-4000-8000-000000000008', 'name' => 'Pengeluaran Lainnya', 'type' => 'expense', 'icon_key' => 'dots-three-circle'],
        ['id' => '00000000-0000-4000-8000-000000000009', 'name' => 'Gaji & Penghasilan', 'type' => 'income', 'icon_key' => 'wallet'],
        ['id' => '00000000-0000-4000-8000-000000000010', 'name' => 'Bonus & Komisi', 'type' => 'income', 'icon_key' => 'coins'],
        ['id' => '00000000-0000-4000-8000-000000000011', 'name' => 'Penerimaan Piutang', 'type' => 'income', 'icon_key' => 'hand-coins'],
        ['id' => '00000000-0000-4000-8000-000000000012', 'name' => 'Pemasukan Lainnya', 'type' => 'income', 'icon_key' => 'plus-circle'],
    ];

    public function run(): void
    {
        foreach (self::SYSTEM_CATEGORIES as $cat) {
            Category::updateOrCreate(
                ['id' => $cat['id']],
                [
                    'user_id' => null,
                    'name' => $cat['name'],
                    'type' => $cat['type'],
                    'icon_key' => $cat['icon_key'],
                    'is_system' => true,
                    'version' => 1,
                ]
            );
        }
    }
}
