<?php

namespace App\Exceptions;

use RuntimeException;

class DomainConflictException extends RuntimeException
{
    public function __construct(
        string $message,
        public readonly array $conflictState = [],
        public readonly string $errorCode = 'VERSION_CONFLICT'
    ) {
        parent::__construct($message);
    }
}
