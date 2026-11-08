<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\PlaceOrderRequest;
use App\Http\Resources\Api\V1\OrderResource;
use App\Models\Order;
use App\Services\OrderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;

class OrderController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $perPage = min(max((int) $request->query('per_page', 15), 1), 50);

        $orders = $request->user()->orders()
            ->with('items')
            ->latest('placed_at')
            ->orderByDesc('id')
            ->paginate($perPage)
            ->withQueryString();

        return OrderResource::collection($orders);
    }

    /**
     * Send an "Idempotency-Key" header (e.g. a UUID generated when the user
     * taps "Place order") so a retried request never creates a second order.
     */
    public function store(PlaceOrderRequest $request, OrderService $orders): JsonResponse
    {
        $key = $request->header('Idempotency-Key');

        if ($key !== null && (strlen($key) > 100 || trim($key) === '')) {
            throw ValidationException::withMessages(['idempotency_key' => ['The Idempotency-Key header must be 1 to 100 characters.']]);
        }

        [$order, $created] = $orders->place($request->user(), $request->validated(), $key);

        return (new OrderResource($order->load('items')))
            ->response()
            ->setStatusCode($created ? 201 : 200);
    }

    public function show(Order $order): OrderResource
    {
        Gate::authorize('view', $order);

        return new OrderResource($order->load('items'));
    }
}
