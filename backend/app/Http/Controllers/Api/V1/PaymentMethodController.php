<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\PaymentMethodType;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\PaymentMethodRequest;
use App\Http\Resources\Api\V1\PaymentMethodResource;
use App\Models\PaymentMethod;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

class PaymentMethodController extends Controller
{
    private const FIELDS = ['type', 'label', 'brand', 'last4', 'exp_month', 'exp_year', 'provider', 'provider_reference'];

    public function index(Request $request): AnonymousResourceCollection
    {
        return PaymentMethodResource::collection(
            $request->user()->paymentMethods()->orderByDesc('is_default')->latest()->orderByDesc('id')->get()
        );
    }

    public function show(PaymentMethod $paymentMethod): PaymentMethodResource
    {
        Gate::authorize('view', $paymentMethod);

        return new PaymentMethodResource($paymentMethod);
    }

    public function store(PaymentMethodRequest $request): JsonResponse
    {
        // is_default stays false unless the user explicitly sends is_default: true.
        $paymentMethod = DB::transaction(function () use ($request) {
            $paymentMethod = $request->user()->paymentMethods()->make($request->safe()->only(self::FIELDS));
            $paymentMethod->label = $paymentMethod->label ?: $paymentMethod->defaultLabel();
            $paymentMethod->save();

            if ($request->boolean('is_default')) {
                $paymentMethod->markAsDefault();
            }

            return $paymentMethod;
        });

        return (new PaymentMethodResource($paymentMethod->refresh()))->response()->setStatusCode(201);
    }

    public function update(PaymentMethodRequest $request, PaymentMethod $paymentMethod): PaymentMethodResource
    {
        DB::transaction(function () use ($request, $paymentMethod) {
            $paymentMethod->fill($request->safe()->only(self::FIELDS));

            if ($paymentMethod->type === PaymentMethodType::CashOnDelivery) {
                $paymentMethod->fill(['brand' => null, 'last4' => null, 'exp_month' => null, 'exp_year' => null]);
            }

            $paymentMethod->label = $paymentMethod->label ?: $paymentMethod->defaultLabel();

            $paymentMethod->save();

            if ($request->has('is_default')) {
                $request->boolean('is_default')
                    ? $paymentMethod->markAsDefault()
                    : $paymentMethod->forceFill(['is_default' => false])->save();
            }
        });

        return new PaymentMethodResource($paymentMethod->refresh());
    }

    public function destroy(PaymentMethod $paymentMethod): Response
    {
        Gate::authorize('delete', $paymentMethod);

        $paymentMethod->delete();

        return response()->noContent();
    }
}
