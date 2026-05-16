if SERVER then
    util.AddNetworkString("ZB_GiveRole")

    function zb.GiveRole(ply, name, color)
        local roleName = name or "WHO ARE YOU?"
        local roleColor = color or color_white

        hook.Run( "ZB_GettingRole", ply, name )

        if IsValid(ply) then
            ply:SetNWString("ZB_RoleName", roleName)
            ply:SetNWInt("ZB_RoleColorR", roleColor.r or 255)
            ply:SetNWInt("ZB_RoleColorG", roleColor.g or 255)
            ply:SetNWInt("ZB_RoleColorB", roleColor.b or 255)
        end

        net.Start("ZB_GiveRole")
            net.WriteTable({
                name = roleName,
                color = roleColor
            })
        net.Send(ply)
    end
else
    net.Receive("ZB_GiveRole",function()
        LocalPlayer().role = net.ReadTable() or false
    end)
end
