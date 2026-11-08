<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Card expiry is display data like brand and last4 (not secret).
        Schema::table('payment_methods', function (Blueprint $table) {
            $table->unsignedTinyInteger('exp_month')->nullable()->after('last4');
            $table->unsignedSmallInteger('exp_year')->nullable()->after('exp_month');
        });
    }

    public function down(): void
    {
        Schema::table('payment_methods', function (Blueprint $table) {
            $table->dropColumn(['exp_month', 'exp_year']);
        });
    }
};
