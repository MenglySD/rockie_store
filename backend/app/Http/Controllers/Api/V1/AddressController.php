<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\AddressRequest;
use App\Http\Resources\Api\V1\AddressResource;
use App\Models\Address;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

class AddressController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        return AddressResource::collection(
            $request->user()->addresses()->orderByDesc('is_default')->latest()->orderByDesc('id')->get()
        );
    }

    public function show(Address $address): AddressResource
    {
        Gate::authorize('view', $address);

        return new AddressResource($address);
    }

    public function store(AddressRequest $request): JsonResponse
    {
        // is_default stays false unless the user explicitly sends is_default: true.
        $address = DB::transaction(function () use ($request) {
            $address = $request->user()->addresses()->create($request->safe()->except('is_default'));

            if ($request->boolean('is_default')) {
                $address->markAsDefault();
            }

            return $address;
        });

        return (new AddressResource($address->refresh()))->response()->setStatusCode(201);
    }

    public function update(AddressRequest $request, Address $address): AddressResource
    {
        DB::transaction(function () use ($request, $address) {
            $address->update($request->safe()->except('is_default'));

            if ($request->has('is_default')) {
                $request->boolean('is_default')
                    ? $address->markAsDefault()
                    : $address->forceFill(['is_default' => false])->save();
            }
        });

        return new AddressResource($address->refresh());
    }

    public function destroy(Address $address): Response
    {
        Gate::authorize('delete', $address);

        // Another address is NOT promoted to default automatically.
        $address->delete();

        return response()->noContent();
    }
}
