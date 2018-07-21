module EventTrigger

placements = Dict{String, Main.EntityPlacement}(
    "Event" => Main.EntityPlacement(
        Main.Maple.EventTrigger,
        "rectangle"
    )
)

function editingOptions(trigger::Main.Maple.Trigger)
    if trigger.name == "eventTrigger"
        return true, Dict{String, Any}(
            "event" => Main.Maple.event_trigger_events
        )
    end
end

end