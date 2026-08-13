local mod = get_mod("scores")

local iteration_types = {
    ADD = {
        value = function(add_value, old_value)
            return old_value + add_value, add_value
        end,
    },
    DIFF = {
        value = function(new_value, old_value)
            return new_value, math.max(new_value - old_value, 0)
        end,
    },
    ADD_IF_ZERO = {
        value = function(add_value, old_value)
            if old_value == 0 then
                return old_value + add_value, add_value
            else
                return old_value, 0
            end
        end,
    },
}
local base_validation_types = {
    highest = function(data, account_id)
        local best = account_id
        if data[account_id] then
            local score = data[account_id].score or 0
            for name, values in pairs(data) do
                if values.score > score then
                    best = name
                    score = values.score
                end
            end
        end
        return best == account_id, best
    end,
    lowest = function(data, account_id)
        local worst = account_id
        if data[account_id] then
            local score = data[account_id].score or 0
            for name, values in pairs(data) do
                if values.score < score then
                    worst = name
                    score = values.score
                end
            end
        end
        return worst == account_id, worst
    end,
}
local validation_types = {
    ASC = {
        is_best = base_validation_types.highest,
        is_worst = base_validation_types.lowest,
        score = function(self, data, account_id)
            local score = data[account_id].score or 0
            return score
        end,
    },
    DESC = {
        is_best = base_validation_types.lowest,
        is_worst = base_validation_types.highest,
        score = function(self, data, account_id)
            local _, worst = self.is_worst(data, account_id)
            local worst_value = data[worst].score or 0
            local _, best = self.is_best(data, account_id)
            local best_value = data[best].score or 0
            local score = data[account_id].score or 0
            return (best_value - score) + worst_value
        end,
    },
    LOWEST = {
        is_best = base_validation_types.lowest,
        is_worst = base_validation_types.highest,
        score = function(self, data, account_id)
            local _, worst = self.is_worst(data, account_id)
            local worst_value = data[worst].score or 0
            local _, best = self.is_best(data, account_id)
            local best_value = data[best].score or 0
            local score = data[account_id].score or 0
            return (best_value - score) + worst_value
        end,
    },
    BLANK = {
        is_best = base_validation_types.highest,
        is_worst = base_validation_types.lowest,
        score = function(self, data, account_id)
            local score = data[account_id].score or 0
            return score
        end,
    },
}
return {
    validation_types = validation_types,
    iteration_types = iteration_types,
}


