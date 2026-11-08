<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * When each tracking step happened. Filled in by the order status
     * triggers (add_order_status_triggers), also for direct database edits.
     */
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->timestamp('paid_at')->nullable()->after('placed_at');
            $table->timestamp('processing_at')->nullable()->after('paid_at');
            $table->timestamp('shipped_at')->nullable()->after('processing_at');
            $table->timestamp('out_for_delivery_at')->nullable()->after('shipped_at');
            $table->timestamp('delivered_at')->nullable()->after('out_for_delivery_at');
            $table->timestamp('cancelled_at')->nullable()->after('delivered_at');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['paid_at', 'processing_at', 'shipped_at', 'out_for_delivery_at', 'delivered_at', 'cancelled_at']);
        });
    }
};
