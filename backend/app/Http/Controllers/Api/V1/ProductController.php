<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\ProductIndexRequest;
use App\Http\Resources\Api\V1\ProductDetailResource;
use App\Http\Resources\Api\V1\ProductResource;
use App\Models\Product;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ProductController extends Controller
{
    public function index(ProductIndexRequest $request): AnonymousResourceCollection
    {
        $filters = $request->validated();

        $products = Product::query()
            ->active()
            ->with(['images'])
            ->withSum(['variants as total_stock' => fn ($q) => $q->where('is_active', true)], 'stock_quantity')
            ->when($filters['category_id'] ?? null, fn (Builder $q, $categoryId) => $q->where(
                fn (Builder $q) => $q->where('category_id', $categoryId)
                    ->orWhereHas('categories', fn (Builder $c) => $c->whereKey($categoryId))
            ))
            ->when($filters['category_ids'] ?? null, fn (Builder $q, array $categoryIds) => $q->where(
                fn (Builder $q) => $q->whereIn('category_id', $categoryIds)
                    ->orWhereHas('categories', fn (Builder $c) => $c->whereKey($categoryIds))
            ))
            ->when($filters['q'] ?? null, fn (Builder $q, $term) => $q->where(
                fn (Builder $q) => $q->whereLike('title', '%'.$term.'%')->orWhereLike('description', '%'.$term.'%')
            ))
            ->when(isset($filters['min_price']), fn (Builder $q) => $q->where('price', '>=', $filters['min_price']))
            ->when(isset($filters['max_price']), fn (Builder $q) => $q->where('price', '<=', $filters['max_price']))
            ->tap(fn (Builder $q) => $this->applySort($q, $filters['sort'] ?? 'newest'))
            ->paginate($filters['per_page'] ?? 20)
            ->withQueryString();

        return ProductResource::collection($products);
    }

    public function show(Product $product): ProductDetailResource
    {
        abort_unless($product->is_active, 404, 'Product not found.');

        $product->load([
            'category',
            'images',
            'variants',
            'reviews' => fn ($q) => $q->with(['images', 'user:id,avatar_url'])->latest()->limit(3),
        ]);

        return new ProductDetailResource($product);
    }

    private function applySort(Builder $query, string $sort): void
    {
        match ($sort) {
            'price_asc' => $query->orderBy('price')->orderBy('id'),
            'price_desc' => $query->orderByDesc('price')->orderBy('id'),
            'popular' => $query->orderByDesc('sold_count')->orderBy('id'),
            'rating' => $query->orderByDesc('rating_avg')->orderByDesc('review_count')->orderBy('id'),
            default => $query->latest()->orderByDesc('id'),
        };
    }
}
