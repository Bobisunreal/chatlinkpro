//=============================================================================
// ChatUDP.
//	FIXME- Jesus christ, this thing needs a major refactor..
//=============================================================================
class UChatUDP expands UdpLink
config(UChatLink2);

var String QueryChar;

var IPAddr HostIP;
var int  RemotePort;    // Port of the server to connect to.
var int	 ReceivePort ;		// Port to bind for incoming data
var string ServerAddress; // Address of the server to connect
var bool bAccepted;
var IPAddr LastRequest;
var int ClientCount;
var string ServerName;
var playerpawn 	LastPlayer[16];
var String 		NameList[16];
var int Counter;
var chatlinkpro backref;
var color ourcolor;

//=======================
// Client Server Options
//=======================
var(CUDPC) Config String JoinMessage;	// Message sent upon first joining.
Var(CUDPC) config int MaxMessagesPerSecond;
Var(CUDPC) config String BlockedClient[32];
var(CUDPC) config bool bAntiSpam;	
var(CUDPC) config bool bLogErrors;
var(CUDPC) config bool bAcceptDeathmessages;
var bool bSendJoinMsg;					// To send or not to send?!
var int Msgs;
var int Tix;
var String MsgCache[4];
var int cacheindex;

Auto state Active
{
	Begin:
	Sleep(1.0);
	LinkMode = MODE_Text;
	ReceiveMode = rMODE_Event;
	BindPort(ReceivePort,false);
	MaxMessagesPerSecond = Max( Maxmessagespersecond, 1 );
	Msgs=0;	Tix=0;	CacheIndex=0;
	SaveConfig();
	Resolve( ServerAddress );
}

State Request
{
	Function BeginState()
	{
		Log("Requesting login to server...",'chatlink');
		SendText( HostIP, querychar$"Request="$ServerName$querychar );
	}
}

Function ReceivedText( IPAddr IPAddr, String Text )
{
local string Reply,Response;

	If( IPAddr == HostIP )
	{
		Response = Parseoption( Text, "Reply" );
		if( Response != "" )
		{
			If( Response ~= "Reject" )
			{
				Log("Connection rejected by host: "$HostIP.Addr,'chatlink');
				Rejected();
				return;
			}
			Else if ( Response ~= "New" || Response ~= "Old" )
			{
				Log("Connection accepted!",'chatlink');
				bSendJoinMsg = ( Response ~= "New" );
				bAccepted = true;
				Accepted();
				return;
			}

		}
		Else if ( Text == "!Ping" )
		{
			ClientSendtext( GetPingMessage() );
			return;
		}
		If( Left( text, 1 ) == CHR( 135 ) )
			ParseText( Text, IPAddr );
	}
}

State Client
{
	Begin:
	counter=0;
	
	Recheck:
	Counter++;
	Sleep(0.2);
	Test();
	If( Counter % 50 == 0 )
		SendText( HostIP, "Ping!" );	// Ping every 10 seconds to secure connection.
	If( Counter % 1500 == 0 )
	{
	   // Log("resending request",'Event');
		SendText( HostIP, querychar$"Request="$ServerName$querychar );
		// occasaionall , re estabish connection , in case chatlink server went offline.
	}
	Goto 'ReCheck';
}

Function string GetPingMessage()
{
	return "!Ping";
}

event Rejected()
{
	Log("You were rejected from the Master Server. Terminating link.",'Event');
	destroy();
}
event Accepted()
{
	If( bSendJoinMsg && (Level.NetMode == NM_Dedicatedserver || Level.netmode==nm_ListenServer) )
	{
		If( Joinmessage == "" )
			JoinMessage="is online and connected to the UChatLink network!";
		ClientSendText( CHR(135)$QueryChar$"Server="$ServerName$QueryChar$"Message="$JoinMessage$QueryChar$"Type=S"$QueryChar$CHR(135) );
		Log("Successfully connected. Broadcasting JoinMessage..",'Event');
	}
	else if ( !bsendjoinmsg )
	{
		Log("Connection reestablished with Master Server.",'Event');
	}
	Gotostate('Client');
}

event Resolved( IPADDR IPAddr )
{
	Log("Successfully resolved host "$IPADDRTOSTRING(IPAddr));
	IPAddr.Port = RemotePort;
	HostIP = IPADDR;
	// A-ok to start sending messages!
	Gotostate('Request');
}

Function bool ClientSendText( Coerce string Text )
{
	if( !bAccepted ) Return False;
	return SendText( HostIP, Text );
}

Function bool sendtext( IPAddr Addr, string Text )
{
	//Log("Sending "$Text$" to "$Addr.Addr$":"$Addr.Port);
	Super.Sendtext(Addr,Text);
}

Function Bool CanSend(string Sender, string Message, out string Reason)
{
local int i;

	If( Msgs>MaxMessagesPerSecond )
	{
		reason = "(Rate limit exceeded)";
		return False;
	}
	// Check if blocked.
	for( i=0; i<32; i++ )
	{
		If( BlockedClient[i] != "" )
			If( BlockedClient[i] ~= Sender )
			{
				Reason = "(This server is blocked)";
				return False;
			}
	}
	
	// Check for chat flood.
	if( bAntiSpam )
	{
		For(i=0;I<4;i++)
		{
			If( MsgCache[i] != "" )
			{
				If( MsgCache[i] ~= Message ) 
				{
					Reason= "(Repetition)";
					return False;
				}
			}
		}
	}
	return True;
}

Function dumpcache()
{
local int i;

	For( i = 0; i < 4; i++ )
		MsgCache[i] = "";
}

Function ParseText( String Text, IPAddr Excluded )
{
local string ServerName,Message,Type,Reason;
local color chatcolor;
	// 1. Parse the message.
	// 2. Broadcast it on the local server.
	// 3. Broadcast it to each client server.

	// hehe
	// hehe

	ServerName = ParseOption( Text, "Server" );
	Message = ParseOption( Text, "Message" );
	Type = ParseOption( Text, "Type" );

	If( ServerName == "Off" ) ServerName = "Offline";

	// II
	If( CanSend( ServerName, Text,Reason ) )
	{
	
	// use eventtype as a netkey.
	//legacy
	// s - chat  d= death
	//n = netcom
	
	
	
	chatcolor.b = int(ParseOption( Text, "Colorb" ));
	chatcolor.g = int(ParseOption( Text, "Colorg" ));
	chatcolor.r = int(ParseOption( Text, "Colorr" ));
	
	// messages may be server with other args in future.
	 If(Message != "" && Message != " " )
	 {
	    backref.proccessglobalmessages( "["$ServerName$"]"@Message$CHR(135), True, Type, Level.Game.MakeColorCode(chatcolor) );
		
		//If( Type == "D" && bAcceptDeathmessages )
		//{
		//		backref.proccessglobalmessages( "["$ServerName$"]"@Message$CHR(135), False, 'DeathMessage' );
		//		//Broadcastmessage( "["$ServerName$"]"@Message$CHR(135), False, 'DeathMessage' );
		//}
		//else
		//{
		//		backref.proccessglobalmessages( "["$ServerName$"]"@Message$CHR(135), True, 'Event' );
		//}	
		//Log("["$ServerName$"]"@Message,'Event');
	
	 }
	 
		Msgs++;
		MsgCache[CacheIndex%4]=Text;
		CacheIndex++;
	}
	else if (bLogerrors)
	{
		Log("Did not locally broadcast message: ["$ServerName$"]"@Message@Reason,'Event');
	}
}

Function String ParseOption( string Line, string Option )
{
local string Tmp,Original,rt;
local int i,L,R;

	Original = Line;
	Line=caps(LINE);
	Option=caps(OPTIOn);
	
	i = InStr( Line, Querychar$Option$"=" );
	If( i == -1 ) return "";
	
	L = i+2+len(option);

	Tmp = Mid( Line, L );
	RT = Tmp;
	i = InStr( RT, Querychar );
	if( i > - 1 )
	{
		R=i;
		tmp = Mid( Original, L, R );
	}
	
	return tmp;
}

	Function playerEntered( Playerpawn Incoming )
	{
	local string Message;
		Message = CHR(135)$QueryChar$"Server="$ServerName$QueryChar$"Message="$Incoming.GetHumanName()@"entered the UChatLink network."$QueryChar$"Type=S"$QueryChar$Chr(135);

		ClientSendText( Message );
	}
	
	Function PlayerLeft( String Leaver )
	{
	local string message; 
		Message = CHR(135)$QueryChar$"Server="$ServerName$QueryChar$"Message="$Leaver@"left the UChatLink network."$QueryChar$"Type=S"$QueryChar$Chr(135);

		ClientSendText( Message );
	}
	
	Function ChangedName( String Old, String NewName )
	{
	local string Message;
		Message= CHR(135)$QueryChar$"Server="$ServerName$QueryChar$"Message="$Old@"changed name to"@NewName$QueryChar$"Type=S"$QueryChar$Chr(135);
		
		ClientSendText( Message );
	}
	
	Function test()
	{
	local pawn p;
	local int i,j;
	local playerpawn Player[16];
	local bool bFound;
	//local string Message;
	
	Tix++;
	If( Tix %5 == 0 )
	{
		Msgs=0;
	}
	If( Tix % 25 == 0 )
		Dumpcache();
		
		If( Level.NetMode != NM_Client )
		{
			For( P = level.pawnlist; P != None; p=p.nextpawn )
			{
				// Add to the temp list.
				If( P.IsA('playerpawn') )
				{
					Player[i] = Playerpawn(P);
					i++;
				}
			}
			
			For( I = 0; I < 16; I++ )
			{	
				bFound=false;	
				If( LastPlayer[i] == None ) break;
	
				For( J = 0; J < 16; J++ )
				{
					If( Player[J] == None ) Break;
					
					If( LastPlayer[I] == Player[J] )
					{
						bFound=true;
						// He's still in the game.
						break;
					}
				}
				if( !bFound )
				{
					PlayerLeft(NameList[i]);		
				}
			}
			
			For( I = 0; I < 16; I++ )
			{
				bFound=false;
				If( Player[i] == None ) Break;	// End of current list of players.
			
				For( J = 0; J < 16; J++ )
				{
					If( LastPlayer[j] == None ) break;	// End of list of previous players.
					
					If( LastPlayer[J] == Player[i] )
					{
						If( NameList[J] != Player[i].GetHumanName() )
						{
							ChangedName(namelist[j],player[i].gethumanname());
						}
						 bFound = true;
						 break;
					}
				}
				if( !bFound )
				{
					Playerentered( Player[i] );
				}
			}
			
			For( I = 0; I < 16; I++ )
			{
				LastPlayer[i] = None;
				If( Player[i] != none )
				{
					LastPlayer[i] = Player[i];	// Update the list for the next comparison.
				}
			}
			
			For( I = 0; I < 16; I++ )
			{	
				If( LastPlayer[i] != none )
				{
					NameList[i] = LastPlayer[i].playerreplicationinfo.playername;
				}
			}
		}
	}

defaultproperties
{
				JoinMessage="some random server joined the chat"
				MaxMessagesPerSecond=999
				bLogErrors=True
				bAcceptDeathmessages=True
}
