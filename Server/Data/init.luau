
local module = {};

module.OnJoining = require(script:WaitForChild('OnJoining'));
module.OnLeaving = require(script:WaitForChild('OnLeaving'));

module = require(script:WaitForChild('Shared')).new(module);

return module
