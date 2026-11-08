<?php

namespace App\Console\Commands;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Models\Order;
use App\Models\User;
use Illuminate\Console\Command;

/**
 * Development helper: moves an order to its next stage, as a payment
 * provider and the warehouse would in production. The customer's
 * notification is created by the database trigger on orders (see the
 * add_order_status_triggers migration), same as for a direct database edit.
 *
 *   To Pay  --pay-->  To Ship  --ship-->  To Receive  --out-->  (out for delivery)  --deliver-->  Completed
 *
 * Examples:
 *   php artisan order:advance                       newest order, next step
 *   php artisan order:advance --user=me@example.com that user's newest order
 *   php artisan order:advance RS261021-AB12CD --to=deliver
 */
class AdvanceOrder extends Command
{
    protected $signature = 'order:advance
        {number? : Order number (default: the newest order)}
        {--user= : Use the newest order of this email address}
        {--to= : pay, ship, out or deliver (default: the next step)}';

    protected $description = 'Move an order to its next stage (pay, ship, out, deliver) for testing';

    public function handle(): int
    {
        $order = $this->findOrder();

        if (! $order) {
            $this->error('No matching order found.');

            return self::FAILURE;
        }

        $step = $this->option('to') ?? $this->nextStep($order);

        if ($step === null) {
            $this->error("Order {$order->number} is {$order->status->value}; there is nothing left to do.");

            return self::FAILURE;
        }

        $error = match ($step) {
            'pay' => $this->pay($order),
            'ship' => $this->ship($order),
            'out' => $this->outForDelivery($order),
            'deliver' => $this->deliver($order),
            default => 'Unknown step. Use pay, ship, out or deliver.',
        };

        if ($error !== null) {
            $this->error($error);

            return self::FAILURE;
        }

        $this->info("Order {$order->number}: {$step} done. Now status={$order->status->value}, payment={$order->payment_status->value}.");

        return self::SUCCESS;
    }

    private function findOrder(): ?Order
    {
        if ($number = $this->argument('number')) {
            return Order::where('number', $number)->first();
        }

        $query = Order::query()->latest('placed_at')->latest('id');

        if ($email = $this->option('user')) {
            $user = User::where('email', $email)->first();

            if (! $user) {
                return null;
            }

            $query->where('user_id', $user->id);
        }

        return $query->first();
    }

    private function nextStep(Order $order): ?string
    {
        return match (true) {
            $order->status === OrderStatus::Cancelled, $order->status === OrderStatus::Delivered => null,
            $order->status === OrderStatus::Shipped => 'out',
            $order->status === OrderStatus::OutForDelivery => 'deliver',
            $this->awaitingPayment($order) => 'pay',
            default => 'ship',
        };
    }

    private function awaitingPayment(Order $order): bool
    {
        return in_array($order->payment_status, [PaymentStatus::Pending, PaymentStatus::Failed], true);
    }

    private function pay(Order $order): ?string
    {
        if (! $this->awaitingPayment($order)) {
            return "Order {$order->number} is not waiting for payment ({$order->payment_status->value}).";
        }

        $order->update(['payment_status' => PaymentStatus::Paid, 'status' => OrderStatus::Processing]);

        return null;
    }

    private function ship(Order $order): ?string
    {
        if (! in_array($order->status, [OrderStatus::Pending, OrderStatus::Processing], true)) {
            return "Order {$order->number} cannot be shipped while {$order->status->value}.";
        }

        if ($this->awaitingPayment($order)) {
            return "Order {$order->number} has not been paid yet. Run --to=pay first.";
        }

        $order->update(['status' => OrderStatus::Shipped]);

        return null;
    }

    private function outForDelivery(Order $order): ?string
    {
        if ($order->status !== OrderStatus::Shipped) {
            return "Order {$order->number} must be shipped before it goes out for delivery.";
        }

        $order->update(['status' => OrderStatus::OutForDelivery]);

        return null;
    }

    private function deliver(Order $order): ?string
    {
        if (! in_array($order->status, [OrderStatus::Shipped, OrderStatus::OutForDelivery], true)) {
            return "Order {$order->number} must be shipped before it is delivered.";
        }

        $changes = ['status' => OrderStatus::Delivered];

        // Cash on delivery is paid when the parcel is handed over.
        if ($order->payment_status === PaymentStatus::Unpaid) {
            $changes['payment_status'] = PaymentStatus::Paid;
        }

        $order->update($changes);

        return null;
    }

}
