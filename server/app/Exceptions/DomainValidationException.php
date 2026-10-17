<?php

namespace App\Exceptions;

use RuntimeException;

class DomainValidationException extends RuntimeException
{
    public function __construct(
        string $message,
        public readonly array $details = [],
        public readonly string $errorCode = 'VALIDATION_FAILED'
    ) {
        parent::__construct($message);
    }
}
