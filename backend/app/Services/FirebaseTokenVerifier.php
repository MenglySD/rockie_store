<?php

namespace App\Services;

use Illuminate\Auth\AuthenticationException;
use InvalidArgumentException;
use Kreait\Firebase\Contract\Auth as FirebaseAuth;
use Kreait\Firebase\Exception\Auth\FailedToVerifyToken;

/**
 * Verifies Firebase ID tokens with the Firebase Admin SDK: signature against
 * Google's public keys, issuer, audience (= project ID), expiry and issued-at.
 */
class FirebaseTokenVerifier
{
    /**
     * @return array{uid: string, email: ?string, email_verified: bool, name: ?string, picture: ?string, provider: ?string}
     *
     * @throws AuthenticationException when the token is malformed, invalid or expired
     */
    public function verify(string $idToken): array
    {
        // Resolved lazily so the rest of the API works without Firebase credentials.
        $auth = app(FirebaseAuth::class);

        try {
            $token = $auth->verifyIdToken($idToken);
        } catch (FailedToVerifyToken|InvalidArgumentException) {
            throw new AuthenticationException('Invalid or expired Firebase token.');
        }

        $claims = $token->claims();
        $firebase = (array) $claims->get('firebase', []);

        return [
            'uid' => (string) $claims->get('sub'),
            'email' => $claims->get('email'),
            'email_verified' => (bool) $claims->get('email_verified', false),
            'name' => $claims->get('name'),
            'picture' => $claims->get('picture'),
            'provider' => $firebase['sign_in_provider'] ?? null,
        ];
    }
}
