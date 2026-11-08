<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Password reset code</title>
</head>
<body style="margin:0;padding:24px;background:#f5f5f5;font-family:Arial,Helvetica,sans-serif;color:#222;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:480px;margin:0 auto;background:#ffffff;border-radius:12px;">
        <tr>
            <td style="padding:32px;">
                <h1 style="margin:0 0 16px;font-size:20px;color:#ff4400;">{{ config('app.name') }}</h1>
                <p style="margin:0 0 16px;">Hi {{ $name }},</p>
                <p style="margin:0 0 16px;">Use this code to reset your password:</p>
                <p style="margin:0 0 24px;font-size:32px;font-weight:bold;letter-spacing:8px;text-align:center;">{{ $otp }}</p>
                <p style="margin:0 0 16px;">The code expires in {{ $expiresInMinutes }} minutes and can be used once.</p>
                <p style="margin:0;color:#777;font-size:13px;">If you did not ask to reset your password, you can ignore this email. Your password will not change.</p>
            </td>
        </tr>
    </table>
</body>
</html>
