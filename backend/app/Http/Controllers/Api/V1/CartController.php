<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\DeliveryMethod;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\AddCartItemRequest;
use App\Http\Requests\Api\V1\ApplyCouponRequest;
use App\Http\Requests\Api\V1\UpdateCartItemRequest;
use App\Http\Resources\Api\V1\CartResource;
use App\Models\Cart;
use App\Models\CartItem;
use App\Services\CartService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class CartController extends Controller
{
    public function __construct(private readonly CartService $carts) {}

    /**
     * GET /cart?delivery_method=express previews express shipping.
     */
    public function show(Request $request): CartResource
    {
        $request->validate(['delivery_method' => ['nullable', Rule::enum(DeliveryMethod::class)]]);

        return $this->respond($this->carts->cartFor($request->user()), $request);
    }

    public function storeItem(AddCartItemRequest $request): JsonResponse
    {
        $cart = $this->carts->addItem($request->user(), $request->integer('product_variant_id'), $request->integer('quantity'));

        return $this->respond($cart, $request)->response()->setStatusCode(201);
    }

    public function updateItem(UpdateCartItemRequest $request, CartItem $item): CartResource
    {
        $cart = $this->carts->updateItem(
            $item,
            $request->has('quantity') ? $request->integer('quantity') : null,
            $request->has('is_selected') ? $request->boolean('is_selected') : null,
        );

        return $this->respond($cart, $request);
    }

    /**
     * PATCH /cart/selection {"is_selected": true} selects (or unselects) every item.
     */
    public function updateSelection(Request $request): CartResource
    {
        $request->validate(['is_selected' => ['required', 'boolean']]);

        return $this->respond($this->carts->selectAll($request->user(), $request->boolean('is_selected')), $request);
    }

    public function destroyItem(Request $request, CartItem $item): CartResource
    {
        Gate::authorize('delete', $item);

        return $this->respond($this->carts->removeItem($item), $request);
    }

    public function applyCoupon(ApplyCouponRequest $request): CartResource
    {
        return $this->respond($this->carts->applyCoupon($request->user(), $request->string('code')), $request);
    }

    public function removeCoupon(Request $request): CartResource
    {
        return $this->respond($this->carts->removeCoupon($request->user()), $request);
    }

    private function respond(Cart $cart, Request $request): CartResource
    {
        $delivery = DeliveryMethod::tryFrom((string) $request->query('delivery_method')) ?? DeliveryMethod::Standard;

        return new CartResource($this->carts->summarize($cart->fresh(), $delivery));
    }
}
