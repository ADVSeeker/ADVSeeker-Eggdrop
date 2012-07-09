#####################################################################################
#              ADV Seeker TCL 0.2                                                   #
#####################################################################################
#       Author: MekDrop                                                             #
#  Script idea: create autoupdated add-on for scanning                              #
#               some type of fucking advertisiment bots                             #
#     Web site: http://www.skycommunity.lt                                          #
# Needed stuff: inidb.tcl >= 0.4.2                                                  #
#               http://www.egghelp.org/cgi-bin/tcl_archive.tcl?mode=download&id=158 #
#               mysqltcl library >= 2.5                                             #
#               http://www.xdobry.de/mysqltcl/index.html                            #
#               fbsql library => 1.0.0                                              #
#               http://www.fastbase.co.nz/fbsql/index.html                          #
#               ini => 1.0.0                                                        #
#               http://www.du.edu/~mschwart/tclextensions.html                      #
#      License: BSD License                                                         #
#####################################################################################

##### Settings ######################################################################

set advINI "scripts/advseeker/adv.ini"
set advINIdb_tclScript "scripts/inidb042/inidb.tcl"
set advDatabaseType "ini" 
#set advDatabaseType "" 

# These settings is only when using SQL database
set advDatabaseHost "localhost"
set advDatabaseUser "root"
set advDatabasePass ""
set advDatabaseName "ircbot"

##### Don't modify these lines if you don't sure ####################################

package require http

set advDBHandle 0

proc advLogWrite {text} {
  putlog "ADVSeeker: $text"
}

proc tryToFindFile {name file} {
   if {[file exists "$file"]} {
      return $file
   }
   if {[file exists "modules/$file"]} {
      return "modules/$file"
   }
   return "";
}

proc tryLoadLibrary {name} {
    set file $name
    append file [info sharedlibextension]
    set file [tryToFindFile $name $file]
    if {[string length $file]>0} {
      advLogWrite " library found here -> $file"
      return [catch {load $file}]
    } else {
      return [catch {package require $name}]
    }
}

set advTryFind 0

switch [string tolower [string trim $advDatabaseType]] {
      "mysqltcl" {
	  if {[tryLoadLibrary "mysqltcl"]==0} {
	     if {[catch {set advDBHandle [mysqlconnect -host $advDatabaseHost -user $advDatabaseUser -password $advDatabasePass -db $advDatabaseName]}]>0} {
         	 die "Failed to load database library. Please look too readme.txt."
	     }
             advLogWrite "using mysqltcl library for database"
	  } else {
             die "Failed to load database library. Please look too readme.txt."
	  }
      }
      "inidb" {
          if {[catch {source $advINIdb_tclScript}]==0} {
 	     advLogWrite "using inidb library for database"
          } else {
	     die "Failed to load database library. Please look too readme.txt."
          }
      }
      "tcl-sql" {
	  if {[tryLoadLibrary "sql"]==0} {
             if {[catch {set advDBHandle [sql connect $advDatabaseHost $advDatabaseUser $advDatabasePass]}]>0} {
        	 die "Failed to load database library. Please look too readme.txt."
	     }
             advLogWrite "using tcl-sql library for database"	  
  	     sql selectdb $advDBHandle $advDatabaseName
	  } else {
	     die "Failed to load database library. Please look too readme.txt."
	  }
      }
      "fbsql" {
         if {[tryLoadLibrary "fbsql"]==0} {
           advLogWrite "using fbsql library for database"
         } else {         	
	   die "Failed to load database library. Please look too readme.txt."
	 }
      }
      "ini" {
         if {[tryLoadLibrary "ini"]==0} {
           advLogWrite "using ini library for database"
         } else {         	
	   die "Failed to load database library. Please look too readme.txt."
	 }          
      }
}

bind NOTC -|- * pub:advNotice
bind msgm -|- * pub:advPrivate
bind msgm -|- "adv*" pub:advPrivateCommand
bind part -|- * pub:advPart

set advNick ""

proc pub:advJoin { nick host hand channel } {
   global advNick advScanOnlyUnknown advBanProxies
   global advStringUsingProxy advStringYouAreMyEnemy
   if {$advBanProxies==1} {
     array set mas {}
     set i 0
     foreach {item} [split $host "@"] {
	 set mas($i) $item
	 set i [expr $i+1]
     }
     if {[string equal [advRead "Hosts" $mas(0)] "proxy"] == 1} {
     	advBan $nick $host $channel $advStringUsingProxy
        advLogWrite "User was using proxy $nick!$host. Banned."
     }
   }
   if {$advScanOnlyUnknown == 1} {
	   if {[advIsEnemy $nick $host]==1} {
		advBan $nick $host $channel $advStringYouAreMyEnemy
	        advLogWrite "Autoban was added to your enemy $nick!$host"
	   }
	   if {[advIsFriend $nick $host]==1} {return;}
           set rez [advRead "Info" "4Scan"]
	   if {[string first " " $rez]>-1} {
		if {[string first " $nick" $rez]>-1} {
		   return;
		}
	   } else {
		if {[string equal $nick $rez]==1} {
		   return;
		}
		
	   }
   	   append rez " "
           append rez $nick	
	   append rez " "
           advWrite "Info" "4Scan" [string trim $rez]
           advWrite "4Scan" "$nick" "$host"
   } else {
        set rez [advRead "Info" "4Scan"]
	append rez " "
        append rez $nick
	append rez " "
        advWrite "Info" "4Scan" [string trim $rez]
        advWrite "4Scan" "$nick" "$host"
   }
}

proc advWrite { section field value } {
    global advDatabaseType advINI advDBHandle
    global advDatabaseHost advDatabaseUser advDatabasePass advDatabaseName
    switch [string tolower [string trim $advDatabaseType]] {
         "mysqltcl" {
             set section [AddSlashes $section]
             set field [AddSlashes $field]
             set value [AddSlashes $value]
	     set sql "DELETE FROM `advseek` WHERE Section = '$section' AND Field = '$field';"
     	     set result [mysqlquery $advDBHandle $sql]
             set sql "INSERT INTO `advseek` ( `Section` , `Field` , `Value` )"
	     append sql "VALUES ("
	     append sql " '$section', '$field', '$value'"
	     append sql ");"
	     set result [mysqlquery $advDBHandle $sql]
	     return 1;
          }
         "inidb" {
             return [ini_write "$advINI" "$section" "$field" "$value"]
         }
	 "tcl-sql" {
             set section [AddSlashes $section]
             set field [AddSlashes $field]
             set value [AddSlashes $value]
	     set sql "DELETE FROM `advseek` WHERE Section = '$section' AND Field = '$field';"
	     sql exec $advDBHandle $sql
             set sql "INSERT INTO `advseek` ( `Section` , `Field` , `Value` )"
	     append sql "VALUES ("
	     append sql " '$section', '$field', '$value'"
	     append sql ");"
	     sql exec $advDBHandle $sql
	     return 1;
	 }
	 "fbsql" {
             set section [AddSlashes $section]
             set field [AddSlashes $field]
             set value [AddSlashes $value]
	     sql connect $advDatabaseHost $advDatabaseUser $advDatabasePass
 	     sql selectdb $advDatabaseName
	     set sql "DELETE FROM `advseek` WHERE Section = '$section' AND Field = '$field';"
	     sql $sql
	     set sql "INSERT INTO `advseek` ( `Section` , `Field` , `Value` )"
	     append sql "VALUES ("
	     append sql " '$section', '$field', '$value'"
	     append sql ");"	    
	     sql $sql
	     sql disconnect
	     return 1;
	 }
	 "ini" {
	     ini set -section "$section" -private "$advINI" -key "$field" -value "$value"
	     return 1;
	 }
    }
}

proc flatten list {return [string map {\{ "" \} ""} $list]}
proc AddSlashes {text} {return [string map -nocase {"\\" "\\\\"	"'" "\\'" "\"" "\\\""} $text];}

proc advRead { section field } {
    global advDatabaseType advINI advDBHandle
    global advDatabaseHost advDatabaseUser advDatabasePass advDatabaseName
    switch [string tolower [string trim $advDatabaseType]] {
         "mysqltcl" {
	     set section [AddSlashes $section]
	     set field [AddSlashes $field]
	     set sql "Select Value FROM `advseek` WHERE Field = '$field' AND Section = '$section';"
	     set result [mysqlquery $advDBHandle $sql]
             set row [mysqlnext $result]
	     if {[string first "query" $result]>-1} {
	         mysqlendquery $result
             } else {
	         return ""
	     }
	     set first [string range $row 0 0]
             if { $first == "\{" } {
	         set row [string range $row 1 end-1]
             }
             return [flatten $row]
          }
         "inidb" {
             return [flatten [ini_read "$advINI" "$section" "$field"]]
         }
	 "tcl-sql" {
             set section [AddSlashes $section]
	     set field [AddSlashes $field]
	     set sql "Select Value FROM `advseek` WHERE Field = '$field' AND Section = '$section';"
	     set result [sql query $advDBHandle $sql]
	     set num_rows_returned [sql numrows $advDBHandle $result]
             if {$num_rows_returned<1} {
	        return ""
             } else {
	        set row [sql fetchrow $conn $res_handle]
	        sql endquery $advDBHandle $result
		return [flatten $row]
             }
	 }
	 "fbsql" {
	    set section [AddSlashes $section]
            set field [AddSlashes $field]
            sql connect $advDatabaseHost $advDatabaseUser $advDatabasePass
 	    sql selectdb $advDatabaseName
	    sql startquery "Select Value FROM `advseek` WHERE Field = '$field' AND Section = '$section';"
	    set rez [sql fetchrow]
	    sql endquery
	    sql disconnect	    
	    return [flatten $rez]
	 }
	 "ini" {
	     set rez [ini get -section "$section" -private "$advINI" -default "" -key "$field"]
	     return [flatten $rez];
	 }
    }
}

proc advReadEx { section conditions } {
    global advDatabaseType advINI advDBHandle
    global advDatabaseHost advDatabaseUser advDatabasePass advDatabaseName
    switch [string tolower [string trim $advDatabaseType]] {
         "mysqltcl" {
             set section [AddSlashes $section]
	     set sql "Select Field, Value FROM `advseek` WHERE $conditions AND Section = '$section';"
	     set result [mysqlquery $advDBHandle $sql]
	     set row ""
	     while {[set rez [::mysql::fetch $result]]!=""} {
	        append row "{$rez} "
	     }
	     mysqlendquery $result
             return $row
          }
	 "fbsql" {
            set section [AddSlashes $section]
            sql connect $advDatabaseHost $advDatabaseUser $advDatabasePass
 	    sql selectdb $advDatabaseName
	    set rez [sql "Select Field, Value FROM `advseek` WHERE $conditions AND Section = '$section';"] 
    	    sql disconnect
	    return $rez
	 }
	 default {
	    return ""
	 }
    }
}

proc advRemove { section field } {
    global advDatabaseType advINI advDBHandle
    global advDatabaseHost advDatabaseUser advDatabasePass advDatabaseName
    switch [string tolower [string trim $advDatabaseType]] {
         "mysqltcl" {
             set section [AddSlashes $section]
             set field [AddSlashes $field]
	     set sql "DELETE FROM `advseek` WHERE Field = '$field' AND Section = '$section';"
	     set result [mysqlquery $advDBHandle $sql]
 	     set sql "OPTIMIZE TABLE `advseek`;"
	     set result [mysqlquery $advDBHandle $sql]
	     mysqlendquery $result
             return 1;
          }
         "inidb" {
             return [ini_remove "$advINI" "$section" "$field"]
         }
	 "tcl-sql" {
             set section [AddSlashes $section]
             set field [AddSlashes $field]
 	     set sql "DELETE FROM `advseek` WHERE Field = '$field' AND Section = '$section';"
	     sql exec $advDBHandle $sql
	     return 1;
	 }
	 "fbsql" {
             set section [AddSlashes $section]
             set field [AddSlashes $field]
	     sql connect $advDatabaseHost $advDatabaseUser $advDatabasePass
 	     sql selectdb $advDatabaseName
     	     set sql "DELETE FROM `advseek` WHERE Field = '$field' AND Section = '$section';"
	     sql $sql
	     sql "OPTIMIZE TABLE `advseek`;"
	     sql disconnect
	     return 1;
	 }
	 "ini" {
	    ini delete -section "$section" -private "$advINI" -key "$field"
	    return 1;
	 }
    }
}

proc advReadSetting {setting} {
  set value [advRead "Settings" $setting]
  if {[string length $value]>0} {
     return $value
  }
  switch  [string tolower $setting]  {
    "messagetype" {
       return "PRIVMSG"
    }
    "scanonlyunknown" {
       return 1
    }
    "autoaddtofriendslist" {
       return 100
    }
    "removebaninterval" {
       return 20
    }
    "banproxies" {
       return 1
    }
    "stringyouhavevirus" {
       return "You have virus in your Mirc scripts. Please delete and reinstall it."
    }
    "stringyouareadv" {
       return "Sorry, but we don't like bots like you!"      
    }
    "stringusingproxy" {
       return "Proxy using in denied."
    }
    "stringyourwishwasfullfiled" {
       return "Your wish was fullfiled."
    }
    "stringyouaremyenemy" {
       return "You are not wellcome here!"
    }
    "stringyouwasbbaned" {
       return "You was banned."
    }
    "agressiveban" {
       return 0
    }
    "onjoinscanenabled" {
       return 1
    }
    "autoupdateenabled" {
       return 1
    }
    "browseragent" {
       return "Mozilla"
    }
    "stringyourwishwasnotfullfiled" {
       return 
    }
    "stringupdatecompleted" {
       return "Update completed."
    }
    "stringsomeerrorsduringupdate" {
       return "Some errors was made during update."  
    }
    "stringvaluewasset" {
       return "Variable's value was changed."
    }
    "stringvariablesvalueis" {
       return "This variable = "
    }
    "stringthisisyourfriend" {
       return "This is your friend! :)"
    }
    "stringthisisnotyourfriend" {
       return "This is not your friend! :("
    }
    "stringthisisyourenemy" {
       return "This is your enemy! :("
    }
    "stringthisisnotyourenemy" {
       return "This is not your enemy! :)"
    }
    "stringlastbanned" {
       return "Last Banned"
     }
    "stringlastremovedban" {
       return "Last Removed Ban"
    } 
    "stringlastonjoinscan" {
       return "Last On Join Scanned"
    }   
    "stringlastnotice"  {
       return "Last Notice" 
    }
    "stringlastpart"  {
       return "Last Channel Part"   
    }
    "stringlastprivatechat"  {
       return "Last Private Chat" 
    }
    "stringlastenemyadded"  {
       return "Last Enemy Added" 
    }  	    
    "stringlastenemycheck"  {
       return "Last Enemy Checked" 
    }
    "stringlastdeleted" {
       return "Last User deleted from known list"
    } 
    "stringlastfriendadded" {
       return "Last Friend Added"
    }    	    
    "stringlastfriendcheck" {
       return "Last Friend Checked"
    } 
    "stringlastvariablevalueset" {
       return "Last Variable Value Set"
    } 
    "stringlastvariablevalueget" {
       return "Last Variable Value Get"
    }    	    	    	    	    
    "stringstatistics" {
       return "Statistics"
    }
    "stringyouarenotmyuser" {
       return "You can't use this command, because I can't find you in my users list"
    }
    "stringenemies" {
       return "My Enemies List"
    }
    "stringfriends" {
       return "My Friends List"
    }
    "stringcurrentversion" {
       return "Current version"
    }
    "stringlastversion" {
       return "Last version"
    }
    "stringcompatibleclients" {
       return "Compatible clients"
    }
    "stringclient" {
       return "Client"
    }
    "stringversion" {
       return "Version"
    }
    "stringhomepage" {
       return "Homepage"
    }
    "stringithinkyouarereklamerbynick" {
       return "I think you are reklamer, because your nick looks similar to random generated..."
    }
    "stringithinkyouarereklamerbyident" {
       return "I think you are reklamer, because your ident looks similar to random generated..."
    }
    "autoaddbot" {
       return 0
    }
    "scanwhoisfieldsinterval" {
       return 20
    }
  }
  return $value
}

proc advWriteSetting {setting value} {
  advWrite "Settings" $setting $value
}

set advOnlyScanTheseChannels [advReadSetting OnlyScanTheseChannels]
set advMessageType [advReadSetting MessageType]
set advScanOnlyUnknown [advReadSetting ScanOnlyUnknown]
set advAutoAddToFriendsList [advReadSetting AutoAddToFriendsList]
set advRemoveBanInterval [advReadSetting RemoveBanInterval]
set advBanProxies [advReadSetting BanProxies]
set advStringYouHaveVirus [advReadSetting StringYouHaveVirus]
set advStringYouAreADV [advReadSetting StringYouAreADV]
set advStringUsingProxy [advReadSetting StringUsingProxy]
set advStringYourWishWasFullfiled [advReadSetting StringYourWishWasFullfiled]
set advStringYouAreMyEnemy [advReadSetting StringYouAreMyEnemy]
set advStringYouWasBanned [advReadSetting StringYouWasBanned]
set advAgressiveBan [advReadSetting AgressiveBan]
set advOnJoinScanEnabled [advReadSetting OnJoinScanEnabled]
set advAutoUpdateEnabled [advReadSetting AutoUpdateEnabled]
set advAgent [advReadSetting BrowserAgent]
set advStringYourWishWasNotFullfiled [advReadSetting StringYourWishWasNotFullfiled]
set advOutsideActionType [advReadSetting OutsideActionType]
set advOutsideAction [advReadSetting OutsideAction]
set advEuralisticScan [advReadSetting EuralisticScan]
set advCurrentVersion 0.2
set advScanWhoisFieldsInterval [advReadSetting ScanWhoisFieldsInterval]

bind MODE -|- * pub:advChangeMode
bind NICK -|- * pub:advNickChange

utimer $advScanWhoisFieldsInterval advScanNow

proc advScanNow {} {
   global advNick advScanOnlyUnknown
   global advScanWhoisFieldsInterval
   set nick [advRead "Info" "4Scan"]
   set nick [string trim $nick]
   if {[string trim $nick]==""} {
       utimer $advScanWhoisFieldsInterval advScanNow
       return 
   }
   advWrite "Info" "4Scan" [lrange $nick 1 end]
   set nick [lindex $nick 0]
   set host [advRead "4Scan" "$nick"]
   advRemove "4Scan" $nick
   if {[onchan $nick]==0} {
       advLogWrite "user $nick is not on known channels, so checking was canceled"
       utimer $advScanWhoisFieldsInterval advScanNow
       return       
   }
   advLogWrite "scanning $nick..."     
   set advNick $nick
   putquick "WHOIS $nick"
   bind RAW - 311 adv_whois:info
   bind RAW - 301 adv_whois:away
   if {$advScanOnlyUnknown==1} {
     advWrite "DontScan" "$nick!$host" [clock scan now]
     set nr [advRead "Scanned" "$nick!$host"]
     advWrite "Scanned" "$nick!$host" [expr $nr+1]
   }
   utimer $advScanWhoisFieldsInterval advScanNow
}

proc pub:advChangeMode { nick host handle channel mode victim } {
  global advScanOnlyUnknown
  if {$advScanOnlyUnknown == 1} {
    if {$mode=="+o"} {
      if { [advIsFriend $victim "nothing@but.you.lt"] == 1 } {return;}
      if {[string tolower $nick] == "chanserv"} {
        advWrite "Known" "$victim!*@*" "friend"
        advLogWrite "$victim!*@* added to friends list"
        advWrite "Stats" "LastFriendAdded" "$victim!*@*"
      }
    }
    if {$mode=="+v"} {
      if {[string tolower $nick] == "chanserv"} {
        if { [advIsFriend $victim "nothing@but.you.lt"] == 1 } {return;}
        advWrite "Known" "$victim!*@*" "friend"
        advLogWrite "$victim!*@* added to friends list"
        advWrite "Stats" "LastFriendAdded" "$victim!*@*"
      }
    }
    if {$mode=="+h"} {
      if {[string tolower $nick] == "chanserv"} {
        if { [advIsFriend $victim "nothing@but.you.lt"] == 1 } {return;}
        advWrite "Known" "$victim!*@*" "friend"
        advLogWrite "$victim!*@* added to friends list"
        advWrite "Stats" "LastFriendAdded" "$victim!*@*"
      }
    }
  }
  if {$mode=="+b"} {
     advLogWrite "added to ban list ban for removing after some time ($victim)"
     set allbans [advRead "Info" "Bans"]
     advWrite "Info" "Bans" "$allbans $victim"
     advWrite "Bans" "$victim" [clock scan now]
  }
  if {$mode=="-b"} {
     advLogWrite "removed ban from list ($victim)"
     set allbans ""
     foreach item [advRead "Info" "Bans"] {
        if {[string equal $item $victim]==0} {
            append allbans $item
	    append allbans " "
        }
     }
     advWrite "Info" "Bans" "$allbans"
     advRemove "Bans" "$victim"
  }
}

proc pub:advNickChange {nick uhost handle channel newnick} {
   global advScanOnlyUnknown
   if {$advScanOnlyUnknown == 1} {
      if { [advIsFriend $newnick $uhost] == 1 } {return;}
   }
   set rez [advRead "Info" "4Scan"]
   set rez [string trim $rez]
   if {[string first " " $rez]>-1} {
      if {[string first " $newnick" $rez]>-1} {
         return;
      } 
   } else {
      if {[string equal $rez $newnick]==1} {
         return;
      }
   }
   append rez $newnick
   append rez " "
   advWrite "Info" "4Scan" [string trim $rez]
   advWrite "4Scan" "$nick" "$uhost"
   advLogWrite "because user $nick has changed nick to $newnick, added this nick to 4Scan list"
}

proc advBan {nick host channel reason} {
   global advNick advRemoveBanInterval
   advWrite "Stats" "LastBanned" "$nick!$host @ $channel ($reason)"
   switch [string tolower $channel] {
     "!all" {
	advWrite "Known" "$nick!$host" "enemy"
        foreach {item} [split [channels] " "] {
	   if {[advIsUserOnChannel $nick $item]==1} {
	       advBan $nick $host $item $reason
	   }
        }
     } 
     default {
        if {[isop $nick $channel]==1} {
	  return;
	}
        if {[botisop $channel]==1} {
	    set allbans [advRead "Info" "Bans"]
            advWrite "Info" "Bans" "$allbans $nick!$host"
            advWrite "Bans" "$nick!$host" [clock scan now]
	    advRemove "Scanned" "$nick!$host"
#            putquick "MODE $channel +b $nick!$host"
	    pushmode $channel +b "$nick!$host"
            putkick $channel $nick $reason	    
	} else {
    	    set allbans [advRead "Info" "Bans"]
            advWrite "Info" "Bans" "$allbans $nick!$host"
            advWrite "Bans" "$nick!$host" [clock scan now]
	    advRemove "Scanned" "$nick!$host"
	    advLogWrite "need ban in channel $channel"
            if {[advReadSetting "UseChanserv"]==1} {
		putquick "PRIVMSG Chanserv : Ban $channel $nick"
		putquick "PRIVMSG Chanserv : Kick $channel $nick"
	    }
	}
     }
   }
}

proc advIsUserOnChannel { nick channel } {
   set nick [string tolower $nick]
   foreach {item} [split [chanlist $channel] " "] {
     set item [string tolower $item]
     if { [string equal $item $nick] == 1 } {
        return 1;
     }
   } 
   return 0;
}

proc advRemoveBans {} {
   global advRemoveBanInterval
   set allbans [advRead "Info" "Bans"]
   if {$allbans == ""} {
      timer $advRemoveBanInterval advRemoveBans
      return;
   }
   set mas [split $allbans " "]  
   foreach {item} $mas {
     advIfNeedRemoveBan $item
   }
   timer $advRemoveBanInterval advRemoveBans
}

proc advIfNeedRemoveBan {host} {
   global advRemoveBanInterval
   set cban [advRead "Bans" $host]
   set cban [expr $cban + $advRemoveBanInterval * 60]
   set time [clock scan now]
   if {$cban > $time} {return;}
   foreach {channel} [split [channels] " "] {
      if {[botisop $channel]==1} {
         advWrite "Stats" "LastRemovedBan" "$host"
         pushmode $channel -b $host
      } else {
         if {[advReadSetting "UseChanserv"]==1} {
	    advWrite "Stats" "LastRemovedBan" "$host @ $channel"
	    putquick "PRIVMSG Chanserv : Unban $channel $host"
         }
      }
   }
   set allbans [advRead "Info" "Bans"]
   set allbans [string map -nocase {$host " "} $allbans]
   set allbans [string trim $allbans]
   advWrite "Info" "Bans" $allbans
   advRemove "Bans" $host
}

proc adv_whois:info { from keyword arguments } {
   global advAutoAddToFriendsList advEuralisticScan
   set nickname [lindex [split $arguments] 1]
   set ident [lindex [split $arguments] 2]
   set host [lindex [split $arguments] 3]
   set realname [string range [join [lrange $arguments 5 end]] 1 end]
   unbind RAW - 311 adv_whois:info
   advWrite "Stats" "LastOnJoinScan" "$nickname!$ident@$host"
   if {$advEuralisticScan == 1} {
      advLogWrite "Scanning with euralistic scan $nickname..."
      if {[advEuralisticValidate $ident]==1} {
         set msg [advReadSetting "stringithinkyouarereklamerbyident"]
         putquick "PRIVMSG $nickname : $msg"
         advRemove "Scanned" "$nickname!*@*"
         advBan $nickname "$ident@$host" "!all" $msg
	 return
      }
      if {[advEuralisticValidate $nickname]==1} {
         set msg [advReadSetting "stringithinkyouarereklamerbynick"]
         putquick "PRIVMSG $nickname : $msg"
         advRemove "Scanned" "$nickname!*@*"
         advBan $nickname "$ident@$host" "!all" $msg
	 return
      }
      advLogWrite "$nickname is good :)"
   }
   advValidate $nickname $host "" "" $realname "!all"
   advValidate $nickname $host "" "" $ident "!all"
   if {[advRead "Scanned" "$nickname!$host"]>$advAutoAddToFriendsList} {
      advRemove "Scanned" "$nickname!$host"
      advRemove "DontScan" "$nickname!$host"
      advRemove "DontScan" "$nickname!*@*"
      advRemove "Scanned" "$nickname!*@*"
      advWrite "Known" "$nickname!$host" "friend"
      advLogWrite "ADV Seek: automatic adding $nickname!$host to friends list"
   }
}

proc adv_whois:away { from keyword arguments } {
   global advNick
   set awaymessage [string range [join [lrange $arguments 2 end]] 1 end]
   advLogWrite "$advNick awaymsg is: $awaymessage"
   advValidate $advNick " " " " " " $awaymessage "!all"
   unbind RAW - 301 adv_whois:away
}

proc pub:advNotice { nick host hand arg txt } {
   global advAgressiveBan advStringYouAreADV advOutsideActionType
   advWrite "Stats" "LastNotice" "$nick!$host - $arg - $txt"
   if { $advAgressiveBan == 1 } {
       advBan $nick "*@*" "!all" $advStringYouAreADV
       if { [string trim $advOutsideAction] == ""} {
		#i think these fields must be empty
       } else    {   
	       putquick "$advOutsideActionType $advOutsideAction :adv ban $nick"
       }
       advLogWrite "$nick!*@* added to bans list"
       return;	    
   }
   advValidate $nick $host $hand $arg $txt "!all"
}

proc pub:advPart { nick host hand channel msg } {
   advWrite "Stats" "LastPart" "$nick!$host @ $channel ($msg)"
   advValidate $nick $host $hand "" $msg $channel
}

proc pub:advPrivate { nick host hand txt } {
   global advAgressiveBan advStringYouAreADV advOutsideAction advOutsideActionType
   advWrite "Stats" "LastPrivateChat" "$nick!$host - $txt"
   if { $advAgressiveBan == 1 } {
       advBan $nick "*@*" "!all" $advStringYouAreADV
       if { [string trim $advOutsideAction] == ""} {
		#i think these fields must be empty
       } else   {
	       putquick "$advOutsideActionType $advOutsideAction :adv ban $nick"
       }
       advLogWrite "$nick!*@* added to bans list"
       return;	    
   }
   advValidate $nick $host $hand "" $txt "!all"
}

proc advIsFriend { nick host } {
  set fh [advRead "Known" "$nick!$host"]
  if { [string equal $fh "friend"] == 1 } {return 1;}
  set fh [advRead "Known" "$nick!*@*"]
  if { [string equal $fh "friend"] == 1 } {return 1;}
  return 0
}

proc advIsEnemy { nick host } {
  set fh [advRead "Known" "$nick!$host"]
  if { [string equal $fh "enemy"] == 1 } {return 1;}
  set fh [advRead "Known" "$nick!*@*"]
  if { [string equal $fh "enemy"] == 1 } {return 1;}
  return 0
}

set advL1 [list q w t p s d f g h j k z x c v b n m r l]
set advL2 [list e y u i o]

proc advEuralisticValidate {text} {
   set text [string tolower $text]
   set r1 ""
   set r2 ""
   set r3 ""
   set r4 ""
   set r5 ""
   for {set x 0} {$x<[string length $text]} {incr x} {
      set r1 $r2
      set r2 $r3
      set r3 $r4
      set r4 $r5
      set r5 [string index $text $x]
#      putlog "$r1 $r2 $r3 $r4"
      if {[advEV1 $r1 $r2 $r3 $r4 $r5]==0} {
        if {[advEV3 $r1 $r2 $r3 $r4 $r5]==1} {
	   return 1
	} 
      }
   }   
   return 0
}

proc advEV1 {t1 t2 t3 t4 t5} {
   set rez 0
   if {[string equal $t1 $t2]==1} {incr rez;}
   if {[string equal $t1 $t3]==1} {incr rez;}
   if {[string equal $t1 $t4]==1} {incr rez;}
   if {[string equal $t1 $t5]==1} {incr rez;}
   return $rez;
}

proc advEV2 {t1} {
   global advL1 advL2
   if {[lsearch $advL1 $t1]<0} {
      if {[lsearch $advL2 $t1]<0} {
         return 0
      } else {
      	 return 2
      }
   } else {
      return 1
   }
}

proc advEV3 {t1 t2 t3 t4 t5} {
  set v1 [advEV2 $t1]
  set v2 [advEV2 $t2]
  set v3 [advEV2 $t3]
  set v4 [advEV2 $t4]
  set v5 [advEV2 $t5]
  if {$v1==0} {return 0;}
  if {$v2==0} {return 0;}
  if {$v3==0} {return 0;}
  if {$v4==0} {return 0;}
  if {$v5==0} {return 0;}
  if {[advEV4 $v1 $v2 $v3 $v4 $v5]==4} {
     return 1
  } else {
     return 0	
  }
}

proc advEV4 {t1 t2 t3 t4 t5} {
   set rez 0
   if {$t1==$t2} {incr rez;}
   if {$t1==$t3} {incr rez;}
   if {$t1==$t4} {incr rez;}
   if {$t1==$t5} {incr rez;}
   return $rez;
}

proc advValidate { nick host hand arg txt channel} {
    global advStringYouHaveVirus advStringYouAreADV advOutsideAction
    global advEuralisticScan advOutsideActionType
    set txt [string tolower "$txt"]
    set value [advRead "FullStrings" "$txt"]
    set action $advOutsideAction
    switch [string tolower $value] {
	"adv" {
	   if {[advIsFriend $nick $host]==1} {return;}
	   advBan $nick "*@*" "$channel" $advStringYouAreADV
	   if { [string trim $advOutsideAction] == ""} {
		#i think these fields must be empty
	   } else {   
	       putquick "$advOutsideActionType $advOutsideAction :adv ban $nick"
           }
	   advLogWrite "$nick!*@* added to bans list"
	   return;
         }
        "vir" {
	   putquick "PRIVMSG $nick :$advStringYouHaveVirus"
	   return;
        }
    }
   set mas [split $txt " "]
   foreach {item} $mas {
      set value [advRead "BadWords" "$item"]
      switch [string tolower $value] {
	"adv" {
	   if {[advIsFriend $nick $host]==1} {return;}
	   advBan $nick "*@*" "$channel" $advStringYouAreADV
           if { [string trim $advOutsideAction] == ""} {
		#i think these fields must be empty
           } else  {
	       putquick "$advOutsideActionType $advOutsideAction :adv ban $nick"
	   }
	   advLogWrite "$nick!*@* added to bans list"
	   return;
         }
        "vir" {
	   putquick "PRIVMSG $nick :$advStringYouHaveVirus"
	   return;
        }
      }
   }
   foreach {item} [advReadEx "MaskStrings" "1=1"] {
       set value [lindex $item 1]
       set item [lindex $item 0]
       if {[string match -nocase $item $txt]==1} {
	      switch [string tolower $value] {
		"adv" {
		   if {[advIsFriend $nick $host]==1} {return;}
		   advBan $nick "*@*" "$channel" $advStringYouAreADV
	           if { [string trim $advOutsideAction] == ""} {
			#i think these fields must be empty
	           } else  {
		       putquick "$advOutsideActionType $advOutsideAction :adv ban $nick"
		   }
		   advLogWrite "$nick!*@* added to bans list"
		   return;
		 }
	        "vir" {
		   putquick "PRIVMSG $nick :$advStringYouHaveVirus"
		   return;
		}
	      }          
       }
   }
}

proc advUpdate {} {
   global advUI advAgent advINI advAutoUpdateEnabled
   set query [advRead "Info" "UpdateURL"]
   set lmdcode [advRead "Info" "Last-Modified"]
   set lmdcode [string trim "$lmdcode"]
   set lmdcode [md5 "$lmdcode"]
   set token [http::config -useragent $advAgent]
   set token [http::geturl $query]
   set error 0
#   puts stderr ""
   upvar #0 $token state
#   putlog $state(body)
   array set header {}
   foreach {name value} $state(meta) {
	set header("$name") $value
   }
   set lmrcode [string trim $header("Last-Modified")]
   set lmrcode [md5 $lmrcode]
#   putlog "$lmrcode == $lmdcode"
   if { [string equal "$lmrcode" "$lmdcode"] == 1 } {
       if { $advAutoUpdateEnabled == 1 } {
          timer [advRead "Info" "UpdateInterval"] advUpdate
       }
       return
   }
   advLogWrite "Updating database..."
   set cmdType "adv"
   set cmdSection "BadWords"
   set cmdClient "ADV Seeker TCL"
   set mas [split $state(body) "\n"]  
   foreach {item} $mas {
      set command [lindex $item 0]
      set param [lrange $item 1 end]
      switch "$command" {
	  "settype" { set cmdType $param; }
          "setsection" { set cmdSection $param;}
	  "writeini" {
	     if {[advWrite "$cmdSection" "$param" "$cmdType"]==0} {set error 1;}
	  }
	  "setupdateinterval" {
	     if {[advWrite "Info" "UpdateInterval" "$param"]==0} {set error 1;}	  
	  }
	  "setupdateurl" {
	     if {[advWrite "Info" "UpdateURL" "$param"]==0} {set error 1;}	  
	  }
	  "removeini" {
	     if {[advRemove "$cmdSection" "$param"]==0} {set error 1;}	  
	  }
	  "setclient" {
	     set cmdClient $param
	     if {[advWrite "ClientsAndVersions" "$cmdClient" "-"]==0} { set error 1; }
	  }
	  "setversion" {
	     if {[advWrite "ClientsAndVersions" "$cmdClient" "$param"]==0} { set error 1; }	    
	  }
	  "sethomepage" {
	     if {[advWrite "ClientsAndHomepages" "$cmdClient" "$param"]==0} { set error 1; }	   
	  }
     }
   }
   if {$error==0} {
      advWrite "Info" "Last-Modified" $header("Last-Modified")
      set msg [advReadSetting "stringupdatecompleted"]
   } else {
      set msg [advReadSetting "stringsomeerrorsduringupdate"]
   }
   advLogWrite $msg
   if { $advAutoUpdateEnabled == 1 } {
      timer [advRead "Info" "UpdateInterval"] advUpdate
   }
   return $msg
}

bind pub "." "!adv" pub:advCommand

proc pub:advCommandUpdate {nick uhost handle channel text} {
  global advMessageType
  putserv "$advMessageType $channel : [advUpdate]"
}

proc pub:advCommandADV {nick uhost handle channel text} {
  global advMessageType advStringYourWishWasFullfiled advStringYourWishWasNotFullfiled
  set action [lindex $text 0]
  set command [lindex $text 1]
  set params [lrange $text 2 end] 
  switch  [string tolower $action]  {
    "word" {
        switch  [string tolower $command]  {
	   "add" {
	        set rez [advWrite "badwords" "$params" "adv"]
	   }
	   "delete" {
	        set rez [advRemove "badwords" "$params"]
	   }
	}
    }
    "text" {
        switch  [string tolower $command]  {
	   "add" {
	        set rez [advWrite "FullStrings" "$params" "adv"]
	   }
	   "delete" {
	        set rez [advRemove "FullStrings" "$params"]
	   }
	}      
    }
    "mask" {
        switch  [string tolower $command]  {
	   "add" {
	        set rez [advWrite "MaskStrings" "$params" "adv"]
	   }
	   "delete" {
	        set rez [advRemove "MaskStrings" "$params"]
	   }
	}      
    }
  }
  if {$rez==0} {
	putserv "$advMessageType $channel : $advStringYourWishWasNotFullfiled"
  } else {
	putserv "$advMessageType $channel : $advStringYourWishWasFullfiled"
  }
}

proc pub:advCommandVIR {nick uhost handle channel text} {
  global advMessageType advStringYourWishWasFullfiled advStringYourWishWasNotFullfiled
  set action [lindex $text 0]
  set command [lindex $text 1]
  set params [lrange $text 2 end] 
  switch  [string tolower $action]  {
    "word" {
        switch  [string tolower $command]  {
	   "add" {
	        set rez [advWrite "badwords" "$params" "vir"]
	   }
	   "delete" {
	        set rez [advRemove "badwords" "$params"]
	   }
	}
    }
    "text" {
        switch  [string tolower $command]  {
	   "add" {
	        set rez [advWrite "FullStrings" "$params" "vir"]
	   }
	   "delete" {
	        set rez [advRemove "FullStrings" "$params"]
	   }
	}      
    }
    "mask" {
        switch  [string tolower $command]  {
	   "add" {
	        set rez [advWrite "MaskStrings" "$params" "vir"]
	   }
	   "delete" {
	        set rez [advRemove "MaskStrings" "$params"]
	   }
	}      
    }
  }
  if {$rez==0} {
	putserv "$advMessageType $channel : $advStringYourWishWasNotFullfiled"
  } else {
	putserv "$advMessageType $channel : $advStringYourWishWasFullfiled"
  }
}

proc pub:advCommandBans {nick uhost handle channel text} {
  global advMessageType advStringYourWishWasFullfiled advStringYouWasBanned
  advBan $text "*@*" "!all" $advStringYouWasBanned
#  putserv "$advMessageType $channel : $advStringYourWishWasFullfiled"
}

proc pub:advCommandEnemies {nick uhost handle channel text} {
  global advMessageType advStringYourWishWasFullfiled 
  global advDatabaseType advStringYourWishWasNotFullfiled
  set command [lindex $text 0]
  set text [lrange $text 1 end] 
  switch  [string tolower $command]  {
     "add" {
     	advWrite "Known" "$text!*@*" "enemy"
	advWrite "Stats" "LastEnemyAdded" "$text!*@*"
        putserv "$advMessageType $channel : $advStringYourWishWasFullfiled"
     }
     "is" {
       advWrite "Stats" "LastEnemyCheck" "$text"
       if {[advIsEnemy $nick "*@*"]==1} {
          set rez [advReadSetting "stringthisisyourenemy"]
	  putserv "$advMessageType $channel : $rez"
       } else {
          set rez [advReadSetting "stringthisisnotyourenemy"]
	  putserv "$advMessageType $channel : $rez"       	
       }
     }
     "delete" {
        advRemove "Known" "$text!*@*"
        advRemove "Known" "$text"
	advWrite "Stats" "LastDeleted" "$text!*@*"
        putserv "$advMessageType $channel : $advStringYourWishWasFullfiled"
     }
     "list" {
       if {[string equal -nocase $advDatabaseType "ini"]==1} {return 0;}
       if {[string equal -nocase $advDatabaseType "inidb"]==1} {return 0;}
       if {[string equal -nocase $advDatabaseType "tcl-sql"]==1} {return 0;}
       set rez [advReadSetting "stringenemies"]
       putserv "$advMessageType $nick : --------------------------"
       putserv "$advMessageType $nick : $rez"
       putserv "$advMessageType $nick : --------------------------"
       set listby10 ""
       set i 0
       foreach {nick2} [advReadEx "Known" "LCASE(Value) = 'enemy'"] {
         set nick2 [lindex $nick2 0]   
         append listby10 "$nick2  "
	 set i [expr $i + 1]
	 if {$i>9} {
	   putserv "$advMessageType $nick : $listby10"
	   set listby10 ""
	   set i 0
	 }
       }
       putserv "$advMessageType $nick : $listby10"
     }
  }  
}

proc pub:advCommandFriends {nick uhost handle channel text} {
  global advMessageType advStringYourWishWasFullfiled
  global advDatabaseType
  set command [lindex $text 0]
  set text [lrange $text 1 end] 
  switch  [string tolower $command]  {
     "add" {
	advWrite "Known" "$text!*@*" "friend"
	advWrite "Stats" "LastFriendAdded" "$text!*@*"
        putserv "$advMessageType $channel : $advStringYourWishWasFullfiled"
     }
     "is" {
       advWrite "Stats" "LastFriendCheck" "$text"
       if {[advIsFriend $nick "*@*"]==1} {
          set rez [advReadSetting "stringthisisyourfriend"]
	  putserv "$advMessageType $channel : $rez"
       } else {
          set rez [advReadSetting "stringthisisnotyourfriend"]
	  putserv "$advMessageType $channel : $rez"       	
       }
     }
     "delete" {
        advRemove "Known" "$text!*@*"
        advRemove "Known" "$text"
	advWrite "Stats" "LastDeleted" "$text!*@*"
        putserv "$advMessageType $channel : $advStringYourWishWasFullfiled"     
     }
     "list" {
       if {[string equal -nocase $advDatabaseType "ini"]==1} {return 0;}
       if {[string equal -nocase $advDatabaseType "inidb"]==1} {return 0;}
       if {[string equal -nocase $advDatabaseType "tcl-sql"]==1} {return 0;}
       set rez [advReadSetting "stringfriends"]
       putserv "$advMessageType $nick : --------------------------"
       putserv "$advMessageType $nick : $rez"
       putserv "$advMessageType $nick : --------------------------"
       set listby10 ""
       set i 0
       foreach {nick2} [advReadEx "Known" "LCASE(Value) = 'friend'"] {
         set nick2 [lindex $nick2 0]   
         append listby10 "$nick2  "
	 set i [expr $i + 1]
	 if {$i>9} {
	   putserv "$advMessageType $nick : $listby10"
	   set listby10 ""
	   set i 0
	 }
       }
       putserv "$advMessageType $nick : $listby10"
     }

  }  
}

proc pub:advCommandVARS {nick uhost handle channel text} {
  global advMessageType
  set command [lindex $text 0]
  set text [lrange $text 1 end] 
  switch  [string tolower $command]  {
     "set" {
       set variable [lindex $text 0]
       set value [lrange $text 1 end] 
       advWriteSetting $variable $value
       set rez [advReadSetting "StringValueWasSet"]
       putserv "$advMessageType $channel : $rez"
       advWrite "Stats" "LastVariableValueSet" "$variable = $value"
       rehash
     }
     "get" {
       advWrite "Stats" "LastVariableValueGet" "$text"
       set rez [advReadSetting "StringVariablesValueIs"]
       set value [advReadSetting $text]
       putserv "$advMessageType $channel : $rez $value"
     }
  }  
}

proc advShowInfo {field channel} {
   global advMessageType
   set value [advRead "Stats" $field]
   set msg [advReadSetting "String$field"]
   if {[string length [string trim $value]]>0} {
      putserv "$advMessageType $channel : $msg: $value"	
   }
}

proc pub:advCommandInfo {nick uhost handle channel text} {
    global advMessageType advCurrentVersion
    set msg [advReadSetting "StringStatistics"]
    putserv "$advMessageType $nick : ------------------------------------"	
    putserv "$advMessageType $nick : $msg"	
    putserv "$advMessageType $nick : ------------------------------------"	
    advShowInfo "LastBanned" $nick
    advShowInfo "LastRemovedBan" $nick
    advShowInfo "LastOnJoinScan" $nick
    advShowInfo "LastNotice" $nick
    advShowInfo "LastPart" $nick
    advShowInfo "LastPrivateChat" $nick
    advShowInfo "LastEnemyAdded" $nick
    advShowInfo "LastEnemyCheck" $nick
    advShowInfo "LastDeleted" $nick  	    	    
    advShowInfo "LastFriendAdded" $nick
    advShowInfo "LastFriendCheck" $nick
    advShowInfo "LastVariableValueSet" $nick
    advShowInfo "LastVariableValueGet" $nick
    set msg [advReadSetting "StringLastVersion"]
    set value [advRead "ClientsAndVersions" "ADV Seeker TCL"]
    if {[string length [string trim $value]]>0} {
       putserv "$advMessageType $nick : $msg: $value"
    }
    set msg [advReadSetting "StringCurrentVersion"]  
    putserv "$advMessageType $nick : $msg: $advCurrentVersion"    
}

set advValidationSystem "build-in"

if {[info exists auth_loaded]} {
    set advValidationSystem "auth.tcl (c) 2000 Bommer"
}
if {[info exists authflag]} {
    set advValidationSystem "Auth v1.03 by David Proper"
}

proc advValidUser {nick host handle} {
   global advValidationSystem
   switch [string tolower $advValidationSystem]  {
     "auth.tcl (c) 2000 Bommer" {
	return [authok $nick $host $handle]
     }
     "Auth v1.03 by David Proper" {
        return [auth_check $nick $handle]
     }
     "build-in" {
        if {[validuser $nick]==0} {
	  return 0;
        }
	foreach {item} [split [getuser $nick HOSTS] " "] {
		if {[string match -nocase $item "$nick!$host"]==1} {
			return 1;
	        }
	}
	return 0;
     }
   }
}

proc pub:advPrivateCommand {nick host hand txt} {
   set txt [lrange $txt 1 end]
   #putlog $txt
   pub:advCommand $nick $host $hand $nick $txt
}

proc pub:advCommand { nick uhost handle channel text } {
  global advMessageType
  set command [lindex $text 0]
  set text [lrange $text 1 end] 
  switch  [string tolower $command]  {
    "update" {
       if {[advValidUser $nick $uhost $handle]==1} {
          pub:advCommandUpdate $nick $uhost $handle $channel $text
       } else {
	  putserv "$advMessageType $channel : [advReadSetting StringYouAreNotMyUser]"
       }      
    }
    "adv" {
       if {[advValidUser $nick $uhost $handle]==1} {
	  pub:advCommandADV $nick $uhost $handle $channel $text
       } else {
	  putserv "$advMessageType $channel : [advReadSetting StringYouAreNotMyUser]"
       }      

    }
    "vir" {
       if {[advValidUser $nick $uhost $handle]==1} {
          pub:advCommandVIR $nick $uhost $handle $channel $text
       } else {
	  putserv "$advMessageType $channel : [advReadSetting StringYouAreNotMyUser]"
       }      

    }
    "vars" {
       if {[advValidUser $nick $uhost $handle]==1} {
          pub:advCommandVARS $nick $uhost $handle $channel $text
       } else {
	  putserv "$advMessageType $channel : [advReadSetting StringYouAreNotMyUser]"
       }      

    }
    "enemies" {
       if {[advValidUser $nick $uhost $handle]==1} {
          pub:advCommandEnemies $nick $uhost $handle $channel $text
       } else {
	  putserv "$advMessageType $channel : [advReadSetting StringYouAreNotMyUser]"
       }      
    }
    "friends" {
       if {[advValidUser $nick $uhost $handle]==1} {
          pub:advCommandFriends $nick $uhost $handle $channel $text
       } else {
	  putserv "$advMessageType $channel : [advReadSetting StringYouAreNotMyUser]"
       }      
    }
    "ban" {
       if {[advValidUser $nick $uhost $handle]==1} {
          pub:advCommandBans $nick $uhost $handle $channel $text
       } else {
	  putserv "$advMessageType $channel : [advReadSetting StringYouAreNotMyUser]"
       }      
    }
    "info" {
       pub:advCommandInfo $nick $uhost $handle $channel $text
    }
    "clients" {
       pub:advCommandClients $nick $uhost $handle $channel $text
    }
  }
}

proc pub:advCommandClients {nick uhost handle channel text} {
    global advMessageType
    set msg [advReadSetting "StringCompatibleClients"]
    set cln [advReadSetting "StringClient"]
    set url [advReadSetting "StringHomepage"]
    putserv "$advMessageType $nick : ------------------------------------------"	
    putserv "$advMessageType $nick : $msg"	
    foreach {name} [advReadEx "ClientsAndVersions" "0=0"] {
       set version [lindex $name 1]
       set name [lindex $name 0]
       set homepage [advRead "ClientsAndHomepages" $name]
       putserv "$advMessageType $nick : ----------------------------------------"
       putserv "$advMessageType $nick : $cln: $name $version"
       putserv "$advMessageType $nick : $url: $homepage"         
    }
}

if {[advReadSetting AutoAddBot]==1} {
  
  bind kick "-" "#*$botnick" advKick

  proc advKick {nick uhost handle channel target reason} {
    if {[string equal [string tolower $reason] "abusing desync"} {
       adduser $nick $uhost
       chattr $nick +op
       advLogWrite "Autoadded user $nick"
    }
  } 

}

advLogWrite "Loaded!"

if { $advOnJoinScanEnabled == 1 } {   
   if {$advOnlyScanTheseChannels == ""} {
#      unbind join -|- *
      bind join -|- * pub:advJoin
      advLogWrite "Checking All channels on join"
   } else {
      set mas [split $advOnlyScanTheseChannels " "]
      foreach {item} $mas {
         bind join -|- "$item *" pub:advJoin
         advLogWrite "Checking channel $item on join"
      }
   }
} else {
   advLogWrite "OnJoin Scan is Disabled"
}
if { $advAutoUpdateEnabled == 1 } {
   if {$advAutoUpdateEnabled==1} {
     advUpdate
   }
   timer [advRead "Info" "UpdateInterval"] advUpdate
   advLogWrite "AutoUpdate is Enabled"
} else {
   advLogWrite "AutoUpdate is Disabled"
}
if { $advBanProxies == 1 } {
   advLogWrite "Banning proxies is Enabled"
} else {
   advLogWrite "Banning proxies is Disabled"
}
if { $advScanOnlyUnknown == 1 } {
   advLogWrite "Scan only unknown is Enabled"
} else {
   advLogWrite "Scan only unknown is Disabled"
}
if { $advEuralisticScan == 1 } {
   advLogWrite "Euralistic scan is Enabled"
} else {
   advLogWrite "Euralistic scan is Disabled"
}
timer $advRemoveBanInterval advRemoveBans