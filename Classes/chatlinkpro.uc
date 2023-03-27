class chatlinkpro expands Mutator config(UChatLink2);



// this has not been significantly updated since 2015
// this mod works with any 227g, h,i, and j Public build
// will not work with pre-public builds of less then 227J39 !! there is a networking bug in thos builds

// slight modifications were done in 2022 to remove some depeciated ts3/rcon stuff



// whats new?
// ability to send non named  mesages.
// sbility to intersectmessages before they are brodcast.
// some ts3 message url compatibility
// colorcode sharing - each servers  color choose will replicate to all other clients.
// color is send as a rgb value in packet, so extranal programs can use that data.
// colors have there up and downs, if you want to have multiple collers on your servername thats 
// kinda doable in the "realname" 
//allow  long servernames in servername
// filter framework


// 1/16
// fix string len issues in long strings send by users with long names etc.
// it will pack as much dat , then send it in parts.

// 1/17
// fix issues in #players to not return webadmin , and just return in server is empty.

// 1/21
// got getprop , exestring working.


// define filters
Struct F{ 
var() config string Text;
var() config bool block;
var() config string replacewith;
var() config string comment;
};

var(CL)config array<F> Filters;                // filters
var(CL)config array<F> Outgoing_Filters;       // filters
var(CL) config bool bfilter;                   // use filters
var(CL) config int RemotePort;                 // master
var(CL) config int ReceivePort;                // client send back
var(CL) config string ServerAddress;           // master
var(CL) config color ourcolor;                 // color to show as
var(CL) config string realname;                // name to show as
var(CL) config int kullname;                   // cutoff
var(CL) config bool sendbroadcastmessages;     // send this servers map messages to server
var(CL) config bool showbroadcastmessages;     // show other servers map messages ( if they send them)
var(CL) config bool sendleveldataatstart;      // show map name at level start

//var(CL) config bool TryToHideEchos;      // try to not show echos tranations
var(CL) config bool SendTranslation_to_utranslator;      // 
					

var UChatUDP UChatUDP;                         // udplink
var Gamereplicationinfo GRI;                   // used to get servername
var info i;                                    //
var string ServerName;                         // stored servername
var String Query;                              // delimiter for udppacket
var string cat;                                // gametype catagory
var int spamtime;                              // here to prevent  query spam
var playerpawn passtouser;

var string wordlist[500];



function PostBeginPlay()
{
	log("**   ----------ChatLink-----------------------------------",stringtoname("[Chatlink2]"));
	Query = Chr(130);
	AddGameRules();
	Log("**  Original Chatlink  base by pcube 'Jaden' pravin ",stringtoname("[Chatlink2]"));
	Log("**  Chatlink   additions by bobisunreal, ",stringtoname("[Chatlink2]"));

	
	if (realname != "" && realname !=" ")
	{
	// perfer a  proper name. please use no color codes here!
	// you can , but the 'chatlinkcolor' will proceed them.
	// * if you use 0,0,0 as a color , messages are non colored , if you want to use custom codes.
	// but still need tweaking - end it in 'white' code or text will be bs'ed
	
	// warning : chages dont effect instant due to trasnfer of variable.
	servername = realname;
	
	}else{ 
       GRI = Level.Game.GameReplicationInfo;
	   servername = Left( GRI.ShortName, kullname );
	 if( ServerName == "Unreal Server" && Level.netmode != nm_Standalone )
	 {
		ServerName = Left(GRI.AdminName,kullname);
		If( servername == "" )
		ServerName = "???";
	 }	
	 Else if ( Level.netmode == nm_Standalone )
	 {
		ServerName="Off";
	 }
	} 

	If( UChatUDP == None )
	{
		UChatUDP = Spawn(class'UChatUDP');
		UChatUDP.RemotePort = RemotePort;
		UChatUDP.ReceivePort = ReceivePort;
		UChatUDP.ServerAddress = ServerAddress;
		UChatUDP.queryChar = Query;
		UChatUDP.ServerName = ServerName;
		UChatUDP.backref= self;
		UChatUDP.ourcolor=ourcolor;
		
	}
	
	// do some debuging here for  failed binding.
	
	// catagorize out game type if possible
   if (level.game.isa('Coopgame') )  {  cat = "Coop";};
   if (level.game.isa('deathmatchgame') )  { cat = "Deathmatch";};
   
   
 
   // set a delay  and show  the level info
   SetTimer(4.0,false); 	

}




function timer ()                                          
{
      // just send the level info
     If( UChatUDP != None )
	 {
	  
	  if (sendleveldataatstart)
      {
      UChatUDP.ClientSendText(CHR(135)$Query$"Server="$ServerName$
      Query$"Colorb="$ourcolor.b$Query$"Colorg="$ourcolor.g$
      Query$"Message="$"Current level" $ ":"$level.title$ "["$string(level.outer)$".unr] "$cat$"["$string(level.game.class)$"]"$
      Query$"Type="$"S"$Query$CHR(135));
      }else{
	  Log("** Failed to send level data , link is broken (none). check you port settings! ",stringtoname("[Chatlink2]"));
	  }
	 }

}




 
//------------------------------------------------------------------------------------------------------------------
// dump incoming messages into the  game
//-------------------------------------------------------------------------------------------------------------------
function proccessglobalmessages(string msgg,bool annoying,string typemess,string colorcut)
{ 

      // things like this should be done in a gamerule instead to allow flexability., but , i am tring to 
      // move all general gamerules into this single mod, 
	  // in a perfect world, this mod can do stuff without gamerules for compatibility. .

      // these are generally for teamspeak.
	  // or other outside services , like irc.
	  
	  // correct for ts3 url phrasing
	  
	  // only limit server requeasts
	  if (instr(Msgg,"#")!=-1 ) 
      {
	  spamtime = Level.TimeSeconds;	
	  }
	  
	  
	  if (instr(Msgg,"TS3")!=-1 ) // only apply to  hosts with ts3 in name
      {
        msgg = ReplaceStr(Msgg, "[URL]", "");
        msgg = ReplaceStr(Msgg, "[/URL]", "");
        msgg = ReplaceStr(Msgg, "https:", "http:");
	  
	     // try to correct for  missing http in www domains , this probably wont happen tho
	     if (instr(Msgg,"www.")!=-1 )
         {
	     if (instr(Msgg,"http")==-1 )    {msgg = ReplaceStr(Msgg, "www.", "http://www."); };
	     }  

      }
	  
	  //dumpout players list to ouside serverices
	  if (instr(Msgg,"#players")!=-1 )  
	  {
	  log (int(Level.TimeSeconds) - spamtime);
	          //  if ( int(Level.TimeSeconds) - spamtime > 9)
			  //  {
			    dumpplays(none); msgg = "";
				//}
			   
			   
	// spamtime = Level.TimeSeconds;
	  
	 }

	  //dumpout mapdata to non unreal clients
      if (instr(Msgg,"#map")!=-1 ) 
      {
	  log (int(Level.TimeSeconds) - spamtime);
	            //if ( int(Level.TimeSeconds) - spamtime > 9)
			    //{
				//log (int(Level.TimeSeconds) - spamtime);
	            UChatUDP.ClientSendText(CHR(135)$
				Query$"Colorb="$ourcolor.b$Query$"Colorg="$ourcolor.g$
	            Query$"Server="$ServerName$
	            Query$"Message=SERVERRESPONSE : Current level" $ " : "$level.title$ "["$string(level.outer)$".unr] "$cat$"["$string(level.game.class)$"]"$
	            Query$"Type="$"S"$Query$CHR(135));
	            msgg = "";
				//}
	  // TODO : for unreal, this can be improved by only broadcasting to the issuer.....
	  // see next block:
      
      };
  
		  
	
     // blank out server responses
     //	Again , its  mixed here , if you block it here , you have no changce latter, 
	 // so again better to do it sepratly as a mod.
     
	 // for unreal, if some speficic player called #players, only return the 
	 
	 if (instr(Msgg,"SERVERRESPONSE")!=-1 )
     {
	 	 if (passtouser !=none)
	     { // not that it maters , but this user will recive ALL serverresponse packets. we dont have end of packet.
	       // currently  , theres nothing privite over these messages.
	          passtouser.ClientMessage(msgg);
	     };
	 
	 //subclassmelaterserverresponse();
     msgg = "";
     }


// send messages of translation to the universal tranlaator item at F2
if (SendTranslation_to_utranslator && instr(Msgg,"gapi")!=-1 )
    {
	msgg = checkfilterlist(msgg);
	sendmessage_to_tras_item(msgg);
	Return;
	}

	 // filter messages if wanted
	 msgg = checkfilterlist(msgg);
	 
	 
	 
     // broadcast as normal , unless there is a reason not to.
     // use broadcast message - gamerules can intercept later!		
     //	 only issue is that you cant let per player disable with broadcast.
      
	 if (msgg != "" && typemess == "S" && msgg != "" && msgg != " ")	
     {	
	   if (colorcut !="" && colorcut != " " && colorcut != "") // < color = 0,0,0
	   {// if the server sent us colors , use them!
	   Broadcastmessage(colorcut $ msgg, false, 'event');
	   }else{
	   // no colors or server ownere uses custom instring
	   Broadcastmessage(msgg, false, 'event');
       }
	 }
	 
	 
	 
	 if (msgg != "" && typemess == "B" && msgg != "" && msgg != " " && showbroadcastmessages)	
     {	
	   if (colorcut !="" && colorcut != " " && colorcut != "") // < color = 0,0,0
	   {// if the server sent us colors , use them!
	   Broadcastmessage(colorcut $ msgg, false, 'event');
	   }else{
	   // no colors or server owner use custom instring
	   Broadcastmessage(msgg, false, 'event');
       }
	 }
}


function string subclassmelaterserverresponse(string lol)
{
return lol;
}

function string checkfilterlist(string inpacket)
{
local int i;
For( i = 0; i <  Array_Size(Filters) ; i++  )
	         {
				If( Filters[i].text != "" && filters[i].text != " ")
		        {
				  if (instr(inpacket,filters[i].text)!=-1 )
                  {
                   // some text matches detection text
				       if (Filters[i].block)
				       {
					   //log ("Chatlink message  blocked due to filter rule  #"$ i $" (" $ filters[i].text $ ")");
					   return "";
					   }
					   
					   if (Filters[i].replacewith != "" ) // && Filters[i].replacewith != " ")
				       {
					   inpacket = ReplaceStr(inpacket, filters[i].text, Filters[i].replacewith);
					   return inpacket;
					   }
				   
				   
                  }
				
				}
			 }	


}



function string checkPREfilterlist(string inpacket)
{
local int i;
For( i = 0; i <  Array_Size(Outgoing_Filters) ; i++  )
	         {
				If( Outgoing_Filters[i].text != "" && Outgoing_Filters[i].text != " ")
		        {
				  if (instr(inpacket,Outgoing_Filters[i].text)!=-1 )
                  {
                   // some text matches detection text
				       if (Outgoing_Filters[i].block)
				       {
					   //log ("Chatlink message  blocked due to Outgoing_Filters rule  #"$ i $" (" $ Outgoing_Filters[i].text $ ")");
					   return "";
					   }
					   
					   if (Outgoing_Filters[i].replacewith != "" ) // && Outgoing_Filters[i].replacewith != " ")
				       {
					   inpacket = ReplaceStr(inpacket, Outgoing_Filters[i].text, Outgoing_Filters[i].replacewith);
					   return inpacket;
					   }
				   
				   
                  }
				
				}
			 }	


}




function dumpplays(playerpawn p)
{
// dump a list of players to the master.
// the playerpawn is to return it somwhere , but its not possible as is.

 local PlayerReplicationInfo PRI;
 local string ms;
 local int players;
   local PlayerPawn q;
    players = 0;
	
	foreach AllActors(class'PlayerPawn',q)
    {
     PRI=q.PlayerReplicationInfo;
     ms = "id:" $ q.PlayerReplicationInfo.playerid $ "  name:" $  q.PlayerReplicationInfo.playername $ "   ping;" $ q.PlayerReplicationInfo.ping;
	  if (q.PlayerReplicationInfo.playername !="WebAdmin")
	  {
	  players ++;
	  UChatUDP.ClientSendText(CHR(135)$Query$"Server="$ServerName$Query$"Message="$"SERVERRESPONSE" $ ": "$ms$Query$"Type="$"N"$Query$CHR(135));
      }
	  
	  
	  
    }
	
	if (players <1 )
	{
	UChatUDP.ClientSendText(CHR(135)$Query$"Server="$ServerName$Query$"Message="$"SERVERRESPONSE Players : "$players$Query$"Type="$"N"$Query$CHR(135));
	}	
	
	
}




function string getname(playerpawn p)
{ // find the fuckers name
local PlayerReplicationInfo PRI;
PRI=p.PlayerReplicationInfo;
return PRI.PlayerName;
}


function bool handleChat( PlayerPawn Chatting, out string Msg )
    {
	  local int ii,jj,hh,kk;
	  local string strl;
	  
	  
	  
	  
      if (instr(Msg,"#players")!=-1 && chatting != none ) 
      {
	  passtouser = chatting; // remeber this player.
      };
	  
	  // new 11/15/22
	  // allow server to disallow sending certein text out.
	  // like passwords , certein users chats etc
	  msg = checkPREfilterlist(msg);
	  if (msg == "")
	  {
	  return false;
	  };
	  
	  if (msg == " ")
	  {
	  return false;
	  };
	 
	  
	  // 255 is udp packet len- check total - if > 255 , trunacate message to fit.
	  	  
	  // get sytem packet info
	  ii = len(CHR(135)$
	  Query$"Server="$ServerName$
	  Query$"Message=<"$getname(chatting) $ "> : "$Query$"Type="$"S"$Query$"Colorb="$ourcolor.b$Query$"Colorg="$ourcolor.g$Query$"Colorr="$ourcolor.r$Query$CHR(135)
	          );

	  // get message len	  
	  jj = len(msg);
 
	  // data len -  total
	  // hh = usabale chars #
	  hh = 255 - ii;
  
	  
	 // get msg difference
	  kk = jj - hh;
	 //log("kk " $kk);	  
     
	 //send left text up to char limit.
	 UChatUDP.ClientSendText(CHR(135)$Query$"Server="$ServerName$Query$"Message=<"$getname(chatting) $ "> : "$left(Msg,hh)$Query$"Type="$"S"$Query$"Colorb="$ourcolor.b$Query$"Colorg="$ourcolor.g$Query$"Colorr="$ourcolor.r$Query$CHR(135));
	 
	 //send the remainder as a new message
	 if (jj > hh)
     {
     log ("packet to long");
	 strl = right(Msg,kk);
	 UChatUDP.ClientSendText(CHR(135)$
	  Query$"Server="$ServerName$
	  Query$"Message=<"$getname(chatting) $ "> : "$" ... " $strl$Query$"Type="$"S"$Query$"Colorb="$ourcolor.b$Query$"Colorg="$ourcolor.g$Query$"Colorr="$ourcolor.r$Query$CHR(135));

     }	  
	  
	 
	  
	  return true;
	 }
	  


	  
	  
	  

function sendmessage_to_tras_item(string message)
{

	local inventory w;
	local playerpawn p;
	
	foreach AllActors(class'PlayerPawn',p)
    {
	w = p.FindInventoryType(class'Translator');
	if ( w != None )
		Translator(w). NewMessage = message;
	
	}
	
	
}



	

function bool handleBcast( Actor Broadcasting, string Msg )
{

 if (!broadcasting.isa('chatlinkpro') && !broadcasting.isa('UChatUDP')  && sendbroadcastmessages)
 {
 UChatUDP.ClientSendText(CHR(135)$Query$"Server="$ServerName$
 Query$"Colorb="$ourcolor.b$Query$"Colorg="$ourcolor.g$Query$"Color.r="$ourcolor.r$
 Query$"Message="$Msg$
 Query$"Type=B"$Query$CHR(135));
 }
 
return true;
}	
	
	
	

function AddGameRules()
{
	local Chatlink_gr gr;
	gr = Spawn(class'Chatlink_gr');
	gr.MutatorPtr = self;
	if (Level.Game.GameRules == None)
		Level.Game.GameRules = gr;
	else if (gr != None)
		Level.Game.GameRules.AddRules(gr);
}


function breakstring(string cmd,string breakerdelimiter)
{ // some function to un-concat divided strings.
  // dumps to wordlist

    local int i, words;
   cmd=cmd$breakerdelimiter;
   for(i=0;i<500;i++)
   {
     if (i > 499) break;
	 WordList[i]="";
   }
  while ((len(cmd)) > 1)
   {      while(left(cmd,1) != breakerdelimiter )
       { wordlist[words]=wordlist[words]$left(cmd,1);
        cmd=right(cmd,len(cmd)-1);}
     // found one word....
     cmd=right(cmd,len(cmd)-1);
     if ( (wordlist[words]!=breakerdelimiter)&&(wordlist[words]!="") )  words++;  // ignore " " / "" as word itself
   } // end while len(Command) > 1)
  cmd="";
  // executing commands
}

defaultproperties
{
				Filters(0)=(Text="the UChatLink",block=True)
				Filters(1)=(Text="[/URL]‡",comment="url patch v1")
				Filters(2)=(Text="TSBot",ReplaceWith="tsbot €ÿ")
				bfilter=True
				RemotePort=9000
				ReceivePort=27708
				ServerAddress="73.248.62.132"
				ourcolor=(R=255,G=255)
				RealName="Ahmonsters"
				kullname=21
				sendbroadcastmessages=True
				sendleveldataatstart=True
}
