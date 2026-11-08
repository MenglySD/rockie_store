<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\StoreSupportMessageRequest;
use App\Models\SupportMessage;
use Illuminate\Http\JsonResponse;

class SupportMessageController extends Controller
{
    /**
     * Works for guests and signed-in users (optional Bearer token).
     */
    public function store(StoreSupportMessageRequest $request): JsonResponse
    {
        $user = $request->user('sanctum');

        $message = SupportMessage::create([
            'user_id' => $user?->id,
            'name' => $user?->name ?? $request->input('name'),
            'email' => $user?->email ?? $request->input('email'),
            'subject' => $request->input('subject'),
            'message' => $request->input('message'),
        ]);

        return response()->json([
            'message' => 'Thanks! Our support team will get back to you soon.',
            'data' => ['id' => $message->id],
        ], 201);
    }
}
