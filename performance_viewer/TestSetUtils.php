<?php
require_once("Test.php");

class TestSetUtils
{
    public static function FilterBy( $set, $methodCall, $value )
    {
        if (!is_array($set) || count($set) < 1 || !($set[0] instanceof Test))
            throw new ErrorException('!is_array($tests) || count($tests) < 1 || !($tests[0] instanceof Test)');
        if (empty($methodCall) || !is_array($methodCall) || empty($value))
            throw new ErrorException('empty($methodCall) || !is_array($methodCall) || empty($value)');

        $methodName = $methodCall[0];
        $methodArgs = $methodCall[1];
        $result = array();
        foreach ($set as $t)
        {
            if (!is_callable(array($t, $methodName)))
                throw new ErrorException('!is_callable(array($t, $methodName))');

            $objValue = call_user_func(array($t, $methodName), $methodArgs);

            if ($objValue === $value)
                $result[] = $t;
        }

        return $result;
    }

    // Returns array( <sort method> = array(tests) )
    public static function GroupBy( $set, $methodCall )
    {
        if (!is_array($set) || count($set) < 1 || !($set[0] instanceof Test))
            throw new ErrorException('!is_array($tests) || count($tests) < 1 || !($tests[0] instanceof Test)');
        if (empty($methodCall) || !is_array($methodCall))
            throw new ErrorException('empty($methodCall) || !is_array($methodCall)');

        $methodName = $methodCall[0];
        $methodArgs = $methodCall[1];
        $result = array();
        $values = array();
        foreach ($set as $t)
        {
            if (!is_callable(array($t, $methodName)))
                throw new ErrorException('!is_callable(array($t, $methodName))');

            $values[] = call_user_func(array($t, $methodName), $methodArgs);
        }

        foreach ($values as $v)
            $result[$v] = static::FilterBy($set, $methodCall, $v);

        return $result;
    }
}
