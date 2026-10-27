local Validation = {}

function Validation.assertString(value, message)
    assert(
        type(value) == "string" and value ~= "",
        message or "Expected a non-empty string"
    )
end

function Validation.wrapPeripheral(peripheralName)
    Validation.assertString(
        peripheralName,
        "Peripheral name must be a non-empty string"
    )

    local wrapped = peripheral.wrap(peripheralName)

    assert(
        wrapped,
        "Unable to wrap peripheral: " .. peripheralName
    )

    return wrapped
end

return Validation
