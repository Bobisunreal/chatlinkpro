class chatlink_GR expands GameRules;

var chatlinkpro MutatorPtr;





function bool AllowChat( PlayerPawn Chatting, out string Msg )
{
   if  (MutatorPtr!= none)
   {
   return MutatorPtr.handleChat(Chatting,Msg);
   }else{
   return true;
   }
}


function bool AllowBroadcast( Actor Broadcasting, string Msg )
{

   if  (MutatorPtr!= none)
   {
    return MutatorPtr.handlebcast(Broadcasting,Msg);
   }else{
   return true;
   }
}

defaultproperties
{
				bNotifyMessages=True
}
