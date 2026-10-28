<?php

namespace Tests\Feature\Api\V1;

use Tests\TestCase;

class SupabaseSchemaContractTest extends TestCase
{
    public function test_supabase_schema_sql_defines_all_tables_rls_and_rpc_functions(): void
    {
        $sqlPath = base_path('../supabase/schema.sql');
        $this->assertFileExists($sqlPath);
        $sql = (string) file_get_contents($sqlPath);

        $this->assertStringContainsString('CREATE EXTENSION IF NOT EXISTS pgcrypto', $sql);
        $this->assertStringContainsString('CREATE TABLE IF NOT EXISTS public.app_users', $sql);
        $this->assertStringContainsString('CREATE TABLE IF NOT EXISTS public.financial_transactions', $sql);
        $this->assertStringContainsString('CREATE OR REPLACE FUNCTION public.app_register(', $sql);
        $this->assertStringContainsString('CREATE OR REPLACE FUNCTION public.app_login(', $sql);
        $this->assertStringContainsString('CREATE OR REPLACE FUNCTION public.app_logout(', $sql);
        $this->assertStringContainsString('CREATE OR REPLACE FUNCTION public.sync_push(', $sql);
        $this->assertStringContainsString('CREATE OR REPLACE FUNCTION public.sync_pull(', $sql);
        $this->assertStringContainsString('ENABLE ROW LEVEL SECURITY', $sql);

        $guidePath = base_path('../supabase/PANDUAN_SUPABASE.md');
        $this->assertFileExists($guidePath);
    }
}
