<?php

namespace Tests\Unit\Finance;

use App\Services\Finance\InstallmentScheduleGenerator;
use PHPUnit\Framework\TestCase;

class InstallmentScheduleGeneratorTest extends TestCase
{
    public function test_seven_monthly_installments_put_rounding_remainder_on_last_term(): void
    {
        $generator = new InstallmentScheduleGenerator();
        $schedule = $generator->generate(6000000, 7, 'monthly', '2026-08-17');

        $this->assertCount(7, $schedule);
        for ($i = 0; $i < 6; $i++) {
            $this->assertSame(857142, $schedule[$i]['planned_amount']);
            $this->assertSame($i + 1, $schedule[$i]['sequence_no']);
        }
        $this->assertSame(857148, $schedule[6]['planned_amount']);
        $this->assertSame(7, $schedule[6]['sequence_no']);
        $this->assertSame(6000000, array_sum(array_column($schedule, 'planned_amount')));
        $this->assertSame('2026-08-17', $schedule[0]['due_date']);
        $this->assertSame('2027-02-17', $schedule[6]['due_date']);
    }

    public function test_even_division_has_identical_terms(): void
    {
        $generator = new InstallmentScheduleGenerator();
        $schedule = $generator->generate(7000000, 7, 'monthly', '2026-10-17');

        $this->assertCount(7, $schedule);
        foreach ($schedule as $term) {
            $this->assertSame(1000000, $term['planned_amount']);
        }
    }
}
