return function(character)
    return ZombRand(100) < character:getPerkLevel(Perks.Strength) * 10
end
