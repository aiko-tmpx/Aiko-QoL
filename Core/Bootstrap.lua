local addonName, ns = ...
ns.addonName = addonName
ns.Core = ns.Core or {}
ns.UI = ns.UI or {}

local tocVersion = select(4, GetBuildInfo())
ns.tocVersion = tocVersion
ns.isForever = tocVersion >= 16000 and tocVersion < 20000
