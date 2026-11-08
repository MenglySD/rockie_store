<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Order status rules, tracking times and notifications enforced by the
 * database itself, so they also apply when an order is edited directly
 * (pgAdmin, SQL, tinker):
 *
 * - status and payment_status must be known values;
 * - status may only move forward:
 *     pending -> processing -> shipped -> out_for_delivery -> delivered
 *     (pending -> shipped and shipped -> delivered may skip a step)
 *     pending / processing -> cancelled
 * - an order waiting for payment cannot be shipped;
 * - paid_at, processing_at, shipped_at, out_for_delivery_at, delivered_at
 *   and cancelled_at record when each step happened;
 * - the customer gets a notification for each step.
 *
 * Times are written in UTC like the rest of Laravel, whatever the database
 * server's own time zone is.
 */
return new class extends Migration
{
    /** status => [timestamp column, notification type, title, body after the order number] */
    private const STEPS = [
        'processing' => ['processing_at', null, null, null],
        'shipped' => ['shipped_at', 'order_shipped', 'Order shipped', ' is on the way.'],
        'out_for_delivery' => ['out_for_delivery_at', 'order_out_for_delivery', 'Out for delivery', ' is out for delivery and arriving soon.'],
        'delivered' => ['delivered_at', 'order_delivered', 'Order delivered', ' has been delivered. Enjoy!'],
        'cancelled' => ['cancelled_at', 'order_cancelled', 'Order cancelled', ' has been cancelled.'],
    ];

    private const SQLITE_TRIGGERS = [
        'orders_valid_status', 'orders_valid_payment_status', 'orders_status_order', 'orders_ship_unpaid',
        'orders_paid', 'orders_step_processing', 'orders_step_shipped', 'orders_step_out_for_delivery',
        'orders_step_delivered', 'orders_step_cancelled',
    ];

    public function up(): void
    {
        match (DB::getDriverName()) {
            'pgsql' => $this->createPostgresTriggers(),
            'sqlite' => $this->createSqliteTriggers(),
            default => null,
        };
    }

    public function down(): void
    {
        match (DB::getDriverName()) {
            'pgsql' => DB::unprepared(<<<'SQL'
                DROP TRIGGER IF EXISTS orders_status_rules ON orders;
                DROP TRIGGER IF EXISTS orders_status_notifications ON orders;
                DROP FUNCTION IF EXISTS orders_check_status();
                DROP FUNCTION IF EXISTS orders_notify_status();
                SQL),
            'sqlite' => collect(self::SQLITE_TRIGGERS)->each(fn ($name) => DB::unprepared("DROP TRIGGER IF EXISTS {$name}")),
            default => null,
        };
    }

    private function createPostgresTriggers(): void
    {
        DB::unprepared(<<<'SQL'
            CREATE OR REPLACE FUNCTION orders_check_status() RETURNS trigger AS $$
            BEGIN
                IF NEW.status NOT IN ('pending', 'processing', 'shipped', 'out_for_delivery', 'delivered', 'cancelled') THEN
                    RAISE EXCEPTION 'Invalid order status "%". Use pending, processing, shipped, out_for_delivery, delivered or cancelled.', NEW.status;
                END IF;

                IF NEW.payment_status NOT IN ('unpaid', 'pending', 'paid', 'failed', 'refunded') THEN
                    RAISE EXCEPTION 'Invalid payment status "%". Use unpaid, pending, paid, failed or refunded.', NEW.payment_status;
                END IF;

                IF NEW.status IS DISTINCT FROM OLD.status AND NOT (
                    (OLD.status = 'pending' AND NEW.status IN ('processing', 'shipped', 'cancelled'))
                    OR (OLD.status = 'processing' AND NEW.status IN ('shipped', 'cancelled'))
                    OR (OLD.status = 'shipped' AND NEW.status IN ('out_for_delivery', 'delivered'))
                    OR (OLD.status = 'out_for_delivery' AND NEW.status = 'delivered')
                ) THEN
                    RAISE EXCEPTION 'Order % cannot go from "%" to "%". Order: pending -> processing -> shipped -> out_for_delivery -> delivered.', OLD.number, OLD.status, NEW.status;
                END IF;

                IF NEW.status = 'shipped' AND OLD.status <> 'shipped' AND NEW.payment_status IN ('pending', 'failed') THEN
                    RAISE EXCEPTION 'Order % has not been paid yet. Set payment_status to paid first.', OLD.number;
                END IF;

                -- Tracking times.
                IF NEW.payment_status = 'paid' AND OLD.payment_status <> 'paid' THEN
                    NEW.paid_at := (now() AT TIME ZONE 'UTC');
                END IF;

                IF NEW.status IS DISTINCT FROM OLD.status THEN
                    CASE NEW.status
                        WHEN 'processing' THEN NEW.processing_at := (now() AT TIME ZONE 'UTC');
                        WHEN 'shipped' THEN NEW.shipped_at := (now() AT TIME ZONE 'UTC');
                        WHEN 'out_for_delivery' THEN NEW.out_for_delivery_at := (now() AT TIME ZONE 'UTC');
                        WHEN 'delivered' THEN NEW.delivered_at := (now() AT TIME ZONE 'UTC');
                        WHEN 'cancelled' THEN NEW.cancelled_at := (now() AT TIME ZONE 'UTC');
                        ELSE NULL;
                    END CASE;
                END IF;

                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;

            CREATE OR REPLACE FUNCTION orders_notify_status() RETURNS trigger AS $$
            DECLARE
                n_type text;
                n_title text;
                n_body text;
            BEGIN
                IF NEW.payment_status = 'paid' AND OLD.payment_status IN ('pending', 'failed') THEN
                    INSERT INTO user_notifications (user_id, type, title, body, data, created_at, updated_at)
                    VALUES (NEW.user_id, 'order_paid', 'Payment received',
                            'We received your payment for order ' || NEW.number || '. We are preparing it for shipping.',
                            json_build_object('order_id', NEW.id), (now() AT TIME ZONE 'UTC'), (now() AT TIME ZONE 'UTC'));
                END IF;

                IF NEW.status IS DISTINCT FROM OLD.status THEN
                    CASE NEW.status
                        WHEN 'shipped' THEN
                            n_type := 'order_shipped'; n_title := 'Order shipped';
                            n_body := 'Your order ' || NEW.number || ' is on the way.';
                        WHEN 'out_for_delivery' THEN
                            n_type := 'order_out_for_delivery'; n_title := 'Out for delivery';
                            n_body := 'Your order ' || NEW.number || ' is out for delivery and arriving soon.';
                        WHEN 'delivered' THEN
                            n_type := 'order_delivered'; n_title := 'Order delivered';
                            n_body := 'Your order ' || NEW.number || ' has been delivered. Enjoy!';
                        WHEN 'cancelled' THEN
                            n_type := 'order_cancelled'; n_title := 'Order cancelled';
                            n_body := 'Your order ' || NEW.number || ' has been cancelled.';
                        ELSE NULL;
                    END CASE;

                    IF n_type IS NOT NULL THEN
                        INSERT INTO user_notifications (user_id, type, title, body, data, created_at, updated_at)
                        VALUES (NEW.user_id, n_type, n_title, n_body, json_build_object('order_id', NEW.id), (now() AT TIME ZONE 'UTC'), (now() AT TIME ZONE 'UTC'));
                    END IF;
                END IF;

                RETURN NULL;
            END;
            $$ LANGUAGE plpgsql;

            DROP TRIGGER IF EXISTS orders_status_rules ON orders;
            CREATE TRIGGER orders_status_rules
                BEFORE UPDATE OF status, payment_status ON orders
                FOR EACH ROW EXECUTE FUNCTION orders_check_status();

            DROP TRIGGER IF EXISTS orders_status_notifications ON orders;
            CREATE TRIGGER orders_status_notifications
                AFTER UPDATE OF status, payment_status ON orders
                FOR EACH ROW EXECUTE FUNCTION orders_notify_status();
            SQL);
    }

    /**
     * Same rules for the SQLite test database (fixed messages: SQLite's
     * RAISE cannot include values). SQLite BEFORE triggers cannot change
     * NEW, so the tracking times are written by AFTER triggers; those only
     * touch timestamp columns and so do not fire the status triggers again.
     */
    private function createSqliteTriggers(): void
    {
        DB::unprepared(<<<'SQL'
            CREATE TRIGGER orders_valid_status BEFORE UPDATE OF status ON orders
            FOR EACH ROW WHEN NEW.status NOT IN ('pending', 'processing', 'shipped', 'out_for_delivery', 'delivered', 'cancelled')
            BEGIN SELECT RAISE(ABORT, 'Invalid order status. Use pending, processing, shipped, out_for_delivery, delivered or cancelled.'); END;
            SQL);

        DB::unprepared(<<<'SQL'
            CREATE TRIGGER orders_valid_payment_status BEFORE UPDATE OF payment_status ON orders
            FOR EACH ROW WHEN NEW.payment_status NOT IN ('unpaid', 'pending', 'paid', 'failed', 'refunded')
            BEGIN SELECT RAISE(ABORT, 'Invalid payment status. Use unpaid, pending, paid, failed or refunded.'); END;
            SQL);

        DB::unprepared(<<<'SQL'
            CREATE TRIGGER orders_status_order BEFORE UPDATE OF status ON orders
            FOR EACH ROW WHEN NEW.status <> OLD.status AND NOT (
                (OLD.status = 'pending' AND NEW.status IN ('processing', 'shipped', 'cancelled'))
                OR (OLD.status = 'processing' AND NEW.status IN ('shipped', 'cancelled'))
                OR (OLD.status = 'shipped' AND NEW.status IN ('out_for_delivery', 'delivered'))
                OR (OLD.status = 'out_for_delivery' AND NEW.status = 'delivered')
            )
            BEGIN SELECT RAISE(ABORT, 'Order status can only move forward: pending, processing, shipped, out_for_delivery, delivered.'); END;
            SQL);

        DB::unprepared(<<<'SQL'
            CREATE TRIGGER orders_ship_unpaid BEFORE UPDATE OF status, payment_status ON orders
            FOR EACH ROW WHEN NEW.status = 'shipped' AND OLD.status <> 'shipped' AND NEW.payment_status IN ('pending', 'failed')
            BEGIN SELECT RAISE(ABORT, 'This order has not been paid yet. Set payment_status to paid first.'); END;
            SQL);

        DB::unprepared(<<<'SQL'
            CREATE TRIGGER orders_paid AFTER UPDATE OF payment_status ON orders
            FOR EACH ROW WHEN NEW.payment_status = 'paid' AND OLD.payment_status <> 'paid'
            BEGIN
                UPDATE orders SET paid_at = datetime('now') WHERE id = NEW.id;
                INSERT INTO user_notifications (user_id, type, title, body, data, created_at, updated_at)
                SELECT NEW.user_id, 'order_paid', 'Payment received',
                       'We received your payment for order ' || NEW.number || '. We are preparing it for shipping.',
                       json_object('order_id', NEW.id), datetime('now'), datetime('now')
                WHERE OLD.payment_status IN ('pending', 'failed');
            END;
            SQL);

        foreach (self::STEPS as $status => [$column, $type, $title, $body]) {
            $notification = $type === null ? '' : <<<SQL
                INSERT INTO user_notifications (user_id, type, title, body, data, created_at, updated_at)
                VALUES (NEW.user_id, '{$type}', '{$title}', 'Your order ' || NEW.number || '{$body}',
                        json_object('order_id', NEW.id), datetime('now'), datetime('now'));
                SQL;

            DB::unprepared(<<<SQL
                CREATE TRIGGER orders_step_{$status} AFTER UPDATE OF status ON orders
                FOR EACH ROW WHEN NEW.status = '{$status}' AND OLD.status <> '{$status}'
                BEGIN
                    UPDATE orders SET {$column} = datetime('now') WHERE id = NEW.id;
                    {$notification}
                END;
                SQL);
        }
    }
};
