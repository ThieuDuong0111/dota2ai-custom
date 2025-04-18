local U = {}

local dota2team = {
	[1] = {
		['name'] = "Team Falcons";
		['alias'] = "Falcons";
		['players'] = {
			'Malr1ne',
			'Skiter',
			'Sneyking',
			'Cr1t-',
			'ATF',
		};
		['sponsorship'] = 'stcplay';
	},
	[2] = {
		['name'] = "Team Spirit";
		['alias'] = "TSpirit";
		['players'] = {
			'Larl',		
			'Collapse',
			'Miposhka',
			'rue',
			'RADDAN',
		};
		['sponsorship'] = 'BetBoom';
	}
}

local sponsorship = { "RMMAI" };

function U.GetDota2Team()
	local bot_names = {};
	local rand = RandomInt(1, #dota2team);
	local srand = RandomInt(1, #sponsorship);
	if GetTeam() == TEAM_RADIANT then
		while rand % 2 ~= 0 do
			rand = RandomInt(1, #dota2team);
		end
	else
		while rand % 2 ~= 1 do
			rand = RandomInt(1, #dota2team);
		end
	end
	local team = dota2team[rand];
	for _, player in pairs(team.players) do
		if team.sponsorship == "" then
			table.insert(bot_names, team.alias .. "." .. player .. "." .. sponsorship[srand]);
		else
			table.insert(bot_names, team.alias .. "." .. player .. "." .. team.sponsorship);
		end
	end
	return bot_names;
end

return U
