<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\StoreReviewRequest;
use App\Http\Resources\Api\V1\ReviewResource;
use App\Models\Product;
use App\Services\ReviewService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ProductReviewController extends Controller
{
    public function index(Request $request, Product $product): AnonymousResourceCollection
    {
        abort_unless($product->is_active, 404, 'Product not found.');

        $perPage = min(max((int) $request->query('per_page', 10), 1), 50);

        $reviews = $product->reviews()
            ->with(['images', 'user:id,avatar_url'])
            ->latest()
            ->orderByDesc('id')
            ->paginate($perPage)
            ->withQueryString();

        return ReviewResource::collection($reviews);
    }

    public function store(StoreReviewRequest $request, Product $product, ReviewService $reviews): JsonResponse
    {
        abort_unless($product->is_active, 404, 'Product not found.');

        $review = $reviews->create($request->user(), $product, $request->validated());

        return (new ReviewResource($review))->response()->setStatusCode(201);
    }
}
