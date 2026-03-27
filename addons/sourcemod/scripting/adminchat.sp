/**
 * vim: set ts=4 :
 * =============================================================================
 * SourceMod Basic Chat Plugin
 * Implements basic communication commands.
 *
 * SourceMod (C)2004-2008 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#pragma semicolon 1

#include <sourcemod>
#include <multicolors>

#pragma newdecls required

public Plugin myinfo =
{
    name        = "Admin Chat",
    author      = "MSWS",
    description = "Admin chat",
    version     = "1.0.0",
    url         = "http://edgegamers.com"
};

#define CHAT_SYMBOL '@'

int g_iClients[MAXPLAYERS + 1];

public void OnPluginStart() {
    LoadTranslations("adminchat.phrases");

    RegConsoleCmd("sm_chat", Command_SmChat, "Contact / chat with admins");

    RegAdminCmd("sm_say", Command_SmSay, ADMFLAG_CHAT, "sm_say <message> - sends message to all players");
    RegAdminCmd("sm_csay", Command_SmCsay, ADMFLAG_CHAT, "sm_csay <message> - sends centered message to all players");
    RegAdminCmd("sm_hsay", Command_SmHsay, ADMFLAG_CHAT, "sm_hsay <message> - sends hint message to all players");
    RegAdminCmd("sm_psay", Command_SmPsay, ADMFLAG_CHAT, "sm_psay <name or #userid> <message> - sends private message");
    RegAdminCmd("sm_msay", Command_SmMsay, ADMFLAG_CHAT, "sm_msay <message> - sends message as a menu panel");
}

public void OnClientDisconnect(int client) {
    g_iClients[client] = 0;
    for (int i = 1; i <= MaxClients; i++)
        if (g_iClients[i] == client)
            g_iClients[i] = 0;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs) {
    int startidx;
    if (sArgs[startidx] != CHAT_SYMBOL)
        return Plugin_Continue;

    startidx++;
    bool admin = CheckCommandAccess(client, "sm_say", ADMFLAG_CHAT);
    bool team  = StrEqual(command, "say_team");
    if (!team && !StrEqual(command, "say"))
        return Plugin_Continue;
    if (sArgs[startidx] != CHAT_SYMBOL || !admin) {
        char message[256];
        strcopy(message, sizeof(message), sArgs[startidx]);
        if (admin && !team) {
            // sm_say alias
            SendChatToAll(client, message);
            LogAction(client, -1, "\"%L\" triggered sm_say (text %s)", client, message);
            return Plugin_Stop;
        }

        // sm_chat alias
        SendChatToAdmins(client, message);
        LogAction(client, -1, "\"%L\" triggered sm_chat (text %s)", client, message);
        return Plugin_Stop;
    }

    startidx++;

    if (sArgs[startidx] != CHAT_SYMBOL && admin) {
        // sm_psay alias

        char arg[64];

        int len    = BreakString(sArgs[startidx], arg, sizeof(arg));
        int target = -1;
        if (StrEqual(arg, "r", false)) {
            target = g_iClients[client];
            if (target == 0 || !IsValidEntity(target) || !IsClientConnected(target)) {
                PrintToChat(client, "[SM] That player disconnected.");
                return Plugin_Stop;
            }
        } else
            target = FindTarget(client, arg, true, false);
        if (target == -1 || len == -1)
            return Plugin_Stop;

        char message[256];
        strcopy(message, sizeof(message), sArgs[startidx + len]);

        SendPrivateChat(client, target, message);
        return Plugin_Stop;
    }

    startidx++;

    // sm_csay alias
    if (!admin)
        return Plugin_Stop;

    DisplayCenterTextToAll(client, sArgs[startidx]);
    LogAction(client, -1, "\"%L\" triggered sm_csay (text %s)", client, sArgs[startidx]);
    return Plugin_Stop;
}

public Action Command_SmSay(int client, int args) {
    if (args < 1) {
        ReplyToCommand(client, "[SM] Usage: sm_say <message>");
        return Plugin_Handled;
    }

    char text[192];
    GetCmdArgString(text, sizeof(text));

    SendChatToAll(client, text);
    LogAction(client, -1, "\"%L\" triggered sm_say (text %s)", client, text);

    return Plugin_Handled;
}

public Action Command_SmCsay(int client, int args) {
    if (args < 1) {
        ReplyToCommand(client, "[SM] Usage: sm_csay <message>");
        return Plugin_Handled;
    }

    char text[192];
    GetCmdArgString(text, sizeof(text));

    DisplayCenterTextToAll(client, text);

    LogAction(client, -1, "\"%L\" triggered sm_csay (text %s)", client, text);

    return Plugin_Handled;
}

public Action Command_SmHsay(int client, int args) {
    if (args < 1) {
        ReplyToCommand(client, "[SM] Usage: sm_hsay <message>");
        return Plugin_Handled;
    }

    char text[192];
    GetCmdArgString(text, sizeof(text));

    char nameBuf[MAX_NAME_LENGTH];

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i) || IsFakeClient(i)) {
            continue;
        }
        FormatActivitySource(client, i, nameBuf, sizeof(nameBuf));
        PrintHintText(i, "%s: %s", nameBuf, text);
    }

    LogAction(client, -1, "\"%L\" triggered sm_hsay (text %s)", client, text);

    return Plugin_Handled;
}

public Action Command_SmChat(int client, int args) {
    if (args < 1) {
        ReplyToCommand(client, "[SM] Usage: sm_chat <message>");
        return Plugin_Handled;
    }

    char text[192];
    GetCmdArgString(text, sizeof(text));

    SendChatToAdmins(client, text);
    LogAction(client, -1, "\"%L\" triggered sm_chat (text %s)", client, text);

    return Plugin_Handled;
}

public Action Command_SmPsay(int client, int args) {
    if (args < 2) {
        ReplyToCommand(client, "[SM] Usage: sm_psay <name or #userid> <message>");
        return Plugin_Handled;
    }

    char text[192], arg[64];
    GetCmdArgString(text, sizeof(text));

    int len = BreakString(text, arg, sizeof(arg));

    int target = FindTarget(client, arg, true, false);

    if (StrEqual(arg, "r", false)) {
        target = g_iClients[client];
        if (target == 0 || !IsValidEntity(target) || !IsClientConnected(target)) {
            PrintToChat(client, "[SM] That player disconnected.");
            return Plugin_Stop;
        }
    }

    if (target == -1)
        return Plugin_Handled;

    SendPrivateChat(client, target, text[len]);

    return Plugin_Handled;
}

public Action Command_SmMsay(int client, int args) {
    if (args < 1) {
        ReplyToCommand(client, "[SM] Usage: sm_msay <message>");
        return Plugin_Handled;
    }

    char text[192];
    GetCmdArgString(text, sizeof(text));

    SendPanelToAll(client, text);

    LogAction(client, -1, "\"%L\" triggered sm_msay (text %s)", client, text);

    return Plugin_Handled;
}

void SendChatToAll(int client, const char[] message) {
    char nameBuf[MAX_NAME_LENGTH];

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i) || IsFakeClient(i))
            continue;
        FormatActivitySource(client, i, nameBuf, sizeof(nameBuf));
        char msg[256], msgConsole[256];
        Format(msg, sizeof(msg), "%t: %s", "Say all", nameBuf, message);
        strcopy(msgConsole, sizeof(msgConsole), msg);
        CRemoveTags(msgConsole, sizeof(msgConsole));
        CPrintToChat(i, msg);
        PrintToConsole(i, msgConsole);
    }
}

void DisplayCenterTextToAll(int client, const char[] message) {
    char nameBuf[MAX_NAME_LENGTH];

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i) || IsFakeClient(i))
            continue;
        FormatActivitySource(client, i, nameBuf, sizeof(nameBuf));
        PrintCenterText(i, "%s: %s", nameBuf, message);
    }
}

void SendChatToAdmins(int from, const char[] message) {
    bool fromAdmin = CheckCommandAccess(from, "", ADMFLAG_CHAT, true);
    int id         = GetClientUserId(from);
    char msgFromAdmin[256], msgFromAdminConsole[256];
    char msgFromAdminAdmin[256], msgFromAdminAdminConsole[256];
    char msgFromAdminSource[256], msgFromAdminSourceConsole[256];

    Format(msgFromAdmin, sizeof(msgFromAdmin), "%t: %s", "Chat admins", from, message);
    strcopy(msgFromAdminConsole, sizeof(msgFromAdminConsole), msgFromAdmin);
    CRemoveTags(msgFromAdminConsole, sizeof(msgFromAdminConsole));

    Format(msgFromAdminAdmin, sizeof(msgFromAdminAdmin), "%t: %s", "Chat to admins-admin", id, from, message);
    strcopy(msgFromAdminAdminConsole, sizeof(msgFromAdminAdminConsole), msgFromAdminAdmin);
    CRemoveTags(msgFromAdminAdminConsole, sizeof(msgFromAdminAdminConsole));

    Format(msgFromAdminSource, sizeof(msgFromAdminSource), "%t: %s", "Chat to admins-source", from, message);
    strcopy(msgFromAdminSourceConsole, sizeof(msgFromAdminSourceConsole), msgFromAdminSource);
    CRemoveTags(msgFromAdminSourceConsole, sizeof(msgFromAdminSourceConsole));

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i) || !IsValidEntity(i))
            continue;
        if (CheckCommandAccess(i, "", ADMFLAG_CHAT, true)) {
            if (fromAdmin) {
                CPrintToChat(i, msgFromAdmin);
                PrintToConsole(i, msgFromAdminConsole);
            } else {
                CPrintToChat(i, msgFromAdminAdmin);
                PrintToConsole(i, msgFromAdminAdminConsole);
            }
            continue;
        }
        if (from != i)
            continue;
        CPrintToChat(i, msgFromAdminSource);
        PrintToConsole(i, msgFromAdminSourceConsole);
    }
    LogAction(from, -1, "\"%L\" triggered sm_chat (text %s)", from, message);
}

void SendPrivateChat(int client, int target, const char[] message) {
    if (!client)
        PrintToServer("(Private to %N) %N: %s", target, client, message);

    char msg[256], msgConsole[256];
    Format(msg, sizeof(msg), "%t: %s", "Private say to", target, client, message);
    strcopy(msgConsole, sizeof(msgConsole), msg);
    CRemoveTags(msgConsole, sizeof(msgConsole));

    for (int i = 1; i <= MaxClients; i++) {
        if (!CheckCommandAccess(i, "", ADMFLAG_CHAT, true) && i != client && i != target)
            continue;
        CPrintToChat(i, msg);
        PrintToConsole(i, msgConsole);
    }

    g_iClients[client] = target;
}

void SendPanelToAll(int from, char[] message) {
    char title[100];
    Format(title, 64, "%N:", from);

    ReplaceString(message, 192, "\\n", "\n");

    Panel mSayPanel = new Panel();
    mSayPanel.SetTitle(title);
    mSayPanel.DrawItem("", ITEMDRAW_SPACER);
    mSayPanel.DrawText(message);
    mSayPanel.DrawItem("", ITEMDRAW_SPACER);
    mSayPanel.CurrentKey = GetMaxPageItems(mSayPanel.Style);
    mSayPanel.DrawItem("Exit", ITEMDRAW_CONTROL);

    for (int i = 1; i <= MaxClients; i++)
        if (IsClientInGame(i) && !IsFakeClient(i))
            mSayPanel.Send(i, Handler_DoNothing, 10);

    delete mSayPanel;
}

public int Handler_DoNothing(Menu menu, MenuAction action, int param1, int param2) {
    /* Do nothing */
    return 0;
}
