package html;
# Copyright 2011,2018 by James E Dodgen Jr.  MIT Licence
use strict;
use Carp;

my $styles = <<EOF;
<style>
hr {
    display: block;
    margin-top: 0.5em;
    margin-bottom: 0.5em;
    margin-left: auto;
    margin-right: auto;
    border-style: inset;
    border-width: 3px;
}
input[type=checkbox] {width:20px; height:20px;}
table.tbody, tr, td, th{
    border-collapse: collapse;
    }
table.tbody, tr td, th {
    border: 1px solid black;
    }

tr.dark {
    background-color:#B0B0B0 ;
    border: 1px solid black;
    border-collapse: collapse;
}
tr.top {
    vertical-align: top;
    text-align: center;
}
tr.alert {background-color:red;
    border: 1px solid black;
    border-collapse: collapse;
    column-span: 2;
    font-size: 150%;
}

body {
    background-color: tan;
}

a:hover {
    background-color: yellow;
}

div.header {
    background-color:#888888;
    color:white;
    font-family: "Verdana", cursive, sans-serif;
    text-align:left;
    padding-left:5px;
}
div.nav {
    line-height:130%;
    background-color:#888888;
    width:115px;
    padding-left:5px;
    padding-right:5px;
    position:fixed;
    font-family: "Verdana", sans-serif;
    xfont-size: 130%;
    border: 2px solid brown;
    border-radius: 10px;
    text-align: center;
}
div.body {
    padding-left:135px;
    xwidth:600px;
}
div.border {
    xfloat:left;
    padding:5px;
    font-family: "Verdana", sans-serif;
    xborder: 4px solid #a1a1a1;
    xborder-radius: 10px;
}


}
div.footer {
    background-color:black;
    color:white;
    clear:both;
    text-align:left;
    padding:7px;
    font-family: "Comic Sans MS", cursive, sans-serif;
}


.noBorder {
    border:none !important;
}

</style>
EOF

sub menu
{
    my $stuff = <<EOF;
<div class=header>
<title>basicNVR</title>
<h1>basicNVR</h1>
</div>
<div class="nav">
      <a href="configuration">Change<br>Configuration</a><br>
      <hr>
      <a href="main">Cameras</a><br>
      <hr>
      <a href="date">Set<br>Timezone</a><br>
      <hr>
      <a href="template">Maintain<br>Templates</a><br>
      <hr>
</div>
EOF

  return \($styles.$stuff);
}


sub form_action_LAN
{
    return '<form  action="" method=post enctype="application/x-www-form-urlencoded">';
}

sub video_devices
{
my $stuff = <<EOF;
<html>
<body>
<form  action="" method=post enctype="application/x-www-form-urlencoded">
<title>basicNVR</title>
<tmpl_loop name=hidden>
  <input type=hidden name="<tmpl_var name=name>" value="<tmpl_var name=value>">
</tmpl_loop>
<h2>basicNVR Video Viewer</h2>

<br>
<!--
<b>User</b>&nbsp;<input type=text name=user value=<tmpl_var name=user>>&nbsp;
<b>Password</b>&nbsp;<input type=password name=password value=<tmpl_var name=password>>&nbsp;
-->
<span style="color:red"><tmpl_var name=error></span>
<br>
<tmpl_if name=camera_nbr><input type=hidden name=camera_nbr value="<tmpl_var name=camera_nbr>"></tmpl_if>
<tmpl_if name=year><input type=hidden name=year value="<tmpl_var name=year>"></tmpl_if>
<tmpl_if name=month><input type=hidden name=month value="<tmpl_var name=month>"></tmpl_if>
<tmpl_if name=day><input type=hidden name=day value="<tmpl_var name=day>"></tmpl_if>
<tmpl_if name=hour><input type=hidden name=hour value="<tmpl_var name=hour>"></tmpl_if>

<div class=border>
<table class=tbody>
  <tmpl_if name=msg>
    <tr class="alert">
     <th  colspan=100% ><tmpl_var name=msg></th>
    </tr>
  </tmpl_if>
  <tr class=dark>
    <th class=dark>
       <tmpl_if name=camera_nbr>
         <input type=submit name="state" value="Reset Camera">
       <tmpl_else>
         Camera
       </tmpl_if>
    </th>
    <th class=dark>
      <tmpl_if name=year>
         <input type=submit name="state" value="Reset Year">
      <tmpl_else>
            Year
      </tmpl_if>
    </th>
    <th class=dark>
       <tmpl_if name=month>
         <input type=submit name="state" value="Reset Month">
         <tmpl_else>
            Month
        </tmpl_if>
    </th>
    <th class=dark>
      <tmpl_if name=day>
         <input type=submit name="state" value="Reset Day">
       <tmpl_else>
            Day
       </tmpl_if>
    </th>
    <th class=dark>
       <tmpl_if name=hour>
         <input type=submit name="state" value="Reset Hour">
       <tmpl_else>
            Hour
      </tmpl_if>
    </th>
    <th class=dark>
        Videos
    </th>
  </tr>
  <tr class=top>
   <td class=main>
   <tmpl_if name=camera_nbr>

    <img height=120 width=160 src="/snapshots/<tmpl_var name=camera_nbr>/lastsnap.jpg"><br>
    <b><tmpl_var name=camera_name></b>
      <tmpl_if name=ffmpeg_output_movies>
         <br>Not Collecting Video
      </tmpl_if>
    <tmpl_else>
    <table>
    <tmpl_loop name=video_cameras>
    <tr>
     <td>
      <!-- <input type="image" height=120 width=160 src="/camera/<tmpl_var name=name>" name="select_camera" value="<tmpl_var name=nbr>"> -->
      <button type="submit" name="select_camera" value="<tmpl_var name=nbr>">
       <img height=120 width=160 src="/snapshots/<tmpl_var name=nbr>/lastsnap.jpg"><br>
       <br>
       <b><tmpl_var name=camera_name></b>
       <tmpl_unless name=ffmpeg_output_movies>
         <br>Not Collecting Video
      </tmpl_unless>
       <br>
      </button>
     </td>
    </tr>
    </tmpl_loop>
   </table>
   </tmpl_if>
   </td>
  <td>
    <tmpl_if name=select_year>
    <table>
    <tmpl_loop name=years>
    <tr>
    <td>
     <input type=submit name="select_year" value="<tmpl_var name=year>">
     </td>
    </tr>
    </tmpl_loop>
    </table>
    <tmpl_else>
      <b><tmpl_var name=year></b>
    </tmpl_if>
  </td>
  <td>
    <tmpl_if name=select_month>
    <table>
    <tmpl_loop name=months>
    <tr>
    <td>
     <input type=submit name="select_month" value="<tmpl_var name=month>">
     </td>
    </tr>
    </tmpl_loop>
    </table>
    <tmpl_else>
      <b><tmpl_var name=month></b>
    </tmpl_if>
  </td>
  <td>
    <tmpl_if name=select_day>
    <table>
    <tmpl_loop name=days>
    <tr>
     <td>
      <input type=submit name="select_day" value="<tmpl_var name=day>">
     </td>
    </tr>
    </tmpl_loop>
    </table>
    <tmpl_else>
     <tmpl_if name=day>
      <b><tmpl_var name=day></b><br>
        <a href="/nvr/videoget.day.<tmpl_var name=camera_nbr>-<tmpl_var name=year>-<tmpl_var name=month>-<tmpl_var name=day>.mp4" target=_blank>View<br>Day</a><br>

     </tmpl_if>
    </tmpl_if>
  </td>
  <td>
    <tmpl_if name=select_hour>
    <table>
    <tmpl_loop name=hours>
    <tr>
    <td>
     <input type=submit name="select_hour" value="<tmpl_var name=hour>">
     </td>
    </tr>
    </tmpl_loop>
    </table>
    <tmpl_else>
     <tmpl_if name=hour>
      <b><tmpl_var name=hour></b><br>
      <a href="/nvr/videoget.hour.<tmpl_var name=camera_nbr>-<tmpl_var name=year>-<tmpl_var name=month>-<tmpl_var name=day>-<tmpl_var name=hour>.mp4" target=_blank>View<br>Hour</a><br>
      </tmpl_if>
    </tmpl_if>
  </td>
  <td>
    <tmpl_if name=select_video>
    <table>
    <tmpl_loop name=videos>
    <tr>
    <td>
   <!-- <video width="320" height="240" controls preload poster="/camera/<tmpl_var name=camera_name>">
       <source src="/nvr/videoget.<tmpl_var name=rowid>.mp4" type="video/mp4">
    </video>
    <br> -->
    <tmpl_var name=year>-<tmpl_var name=month>-<tmpl_var name=day> <tmpl_var name=hour>:<tmpl_var name=minute>
    <a href="/nvr/videoget.<tmpl_var name=rowid>.mp4" target=_blank>View</a>&nbsp;

       <!-- <button type="submit" name="delete_video" value="<tmpl_var name=rowid>">
       <b>Delete this</b>
       </button> -->
     <!-- <video id='movie' src="/videoget.<tmpl_var name=rowid>.<tmpl_var name=year>-<tmpl_var name=month>-<tmpl_var name=day> <tmpl_var name=hour>:<tmpl_var name=minute>.mp4" controls></video> -->
     <!-- <input type=radio name="getvideo" value="<tmpl_var name=video>"> -->
     </td>
    </tr>
    </tmpl_loop>
    </table>
    <tmpl_else>

    </tmpl_if>
  </td>
  </tr>

</table>
<button type="submit" name="Rebuild_database" value="rebuild">Rebuild database image tables</button>
<!-- <br><a href='https://logout\@<tmpl_var name=ip_addr>'>Logout</a> -->
</div>
<tmpl_var name=msg>
</body>
</html>
EOF
return \($styles.$stuff);
}

sub template
{
my $stuff = <<EOF;
<html>
<tmpl_var name=form_action>
<tmpl_loop name=hidden>
  <input type=hidden name="<tmpl_var name=name>" value="<tmpl_var name=value>">
</tmpl_loop>
<tmpl_var name=menu>
<div class="body"><div class=border>
        <table class="tbody">
          <tmpl_if name=msg>
           <tr class="alert">
            <th colspan=100% >
              <tmpl_var name=msg>
            </th>
           </tr>
          </tmpl_if>
          <tr class="dark">           
            <th>
              Camera Type
            </th>            
            <th colspan=2>
              Camera Interface
            </th>            
          </tr>
          <tr class="dark">            
            <th>
              Name(s)
            </th>            
            <th>
              URL
            </th>
            <th>
              Keepalive
            </th>
          </tr>
          <tmpl_loop name=templates>
          <tr>         
            <td>
            <table class="noBorder">
             <tr class="noBorder">
              <td  class="noBorder">
               <button name="state" value="<tmpl_var name=name>:delete_template" type="submit">Delete</button>
              </td>
              <td  class="noBorder">
                <b><tmpl_var name=name><b>                           
              </td>
             </tr>
            </table>         
            </td>            
             <td align=left>
             <button name="state" value="<tmpl_var name=name>:update_url" type="submit">Update</button>           
             <input type=text name="<tmpl_var name=name>:url"  value="<tmpl_var name=url>" size=100>             
             </td>
             <td align=left>
				<input type="radio" id="on" name="<tmpl_var name=name>:keepalive" value="on"  <tmpl_var name=on_checked>>				
				<label for="on">on</label> 
				<input type="radio" id="off" name="<tmpl_var name=name>:keepalive" value="off" <tmpl_var name=off_checked>>  
				<label for="off">off</label>
            </td>                             
          </tr>
          </tmpl_loop>
          <tr class="dark">           
                     
            <th colspan=3>
              Add New Camera Interface
            </th>            
          </tr>
          <tr class="dark">            
            <th>
              Name
            </th>            
            <th>
              URL
            </th>
            <th>
              Keepalive
            </th>
          </tr>
          <tr>           
            <td align=left>
             <button name="state" value="0:add" type="submit">Add</button>            
              <input type=text name="add_camera_template_name"  value="<tmpl_var name=add_name>">
            </td>
            <td align=left>
             <b>stream</b>&nbsp<input type=text name="add_camera_template_stream_url"  size=100, value="<tmpl_var name=add_stream_url>">
              <!--<b>snapshot</b>&nbsp<input type=text name="add_camera_template_snapshot_url"  size=100, value="<tmpl_var name=add_snapshot_url>"> -->
            </td>
            <td align=left>
				<input type="radio" id="on" name="add_keepalive" value="on" <tmpl_var name=add_on_checked>>				
				<label for="on">on</label> 
				<input type="radio" id="off" name="add_keepalive" value="off" <tmpl_var name=add_off_checked>>  
				<label for="off">off</label>
            </td>
                       
          </tr>
        </table>
    </div></div>
<pre>
<tmpl_var name=email_string>
<tmpl_var name=login_comments>
</pre>
<br>
Templates can have the following:<br>
%USER, %PWD, %CHANNEL 
<br>
</html>

EOF
return \($styles.$stuff);
}

sub view_video
{
my $stuff = <<EOF;
<!DOCTYPE html>
<html>
<body>
<h2>
basicNVR Viewer
</h2>
<h1><tmpl_var name=name></h1>
<video width="800" controls autoplay>
  <source src="<tmpl_var name=video>" type="video/mp4">
  Your browser does not support HTML5 video.
</video>
<br>
<a href="<tmpl_var name=video>" download>Download</a><br>

</body>
</html>
EOF
#return \($styles.$stuff);
return \$stuff;
}

sub simple_list
{
my $stuff = <<EOF;
<html>
<body bgcolor=tan>
<title>basicNVR</title>
<font size=2 face="geneva, helvetica, sans serif">
<tmpl_loop name=hidden>
  <input type=hidden name="<tmpl_var name=name>" value="<tmpl_var name=value>">
</tmpl_loop>
<table border=1>
  <tr>
    <th align=center colspan=100%>
       <font color=green size=+1><tmpl_var name=desc></font>
    </th>
  </tr>
  <tmpl_loop name=items>
  <tr>
    <th align=CENTER>
       <a href='<tmpl_var name=link>'><tmpl_var name=item></a>
    </th>
  </tr>
  </tmpl_loop>
</table>
</font>
</body>
</html>
EOF
return \$stuff;
}

sub cameras
{
my $stuff = <<EOF;
<html>
<tmpl_var name=form_action>
<tmpl_loop name=hidden>
  <input type=hidden name="<tmpl_var name=name>" value="<tmpl_var name=value>">
</tmpl_loop>
<tmpl_var name=menu>
<div class="body"><div class=border>
        <table class="tbody">
          <tmpl_if name=msg>
           <tr class="alert">
            <th  colspan=100% ><tmpl_var name=msg></th>
           </tr>
          </tmpl_if>
          
          <tr class="dark">
            <th>
              &nbsp;
            </th>
            <th>
              Camera name<br>&<br>Options
            </th>
            <th>
              Protocol
            </th>
            <th>
              ADDR
            </th>
            <th>
              User
            </th>
            <th>
              Motion Trigger<Br>Areas
            </th>
          </tr>
          <tmpl_loop name=cameras>
          <tr>
            <td align=left>
              <tmpl_if name=camera_name>
                <a href="http://<tmpl_var name=ip_addr>:<tmpl_var name=port>" target="_blank">
                 <tmpl_if name=portrait >
                  <img height=256 width=144 src="/snapshot/<tmpl_var name=camera_name>">
                 <tmpl_else>
                   <img height=144 width=256 src="/snapshot/<tmpl_var name=camera_name>">
                 </tmpl_if>
                </a>
                <!-- <img height=120 width=160 src="/snapshot/<tmpl_var name=camera_name>"> -->
              </tmpl_if>
            </td>
            <td align=left>
              <b>
              <input type=submit name="state" value="Update">
              <button name="state" value="Delete <tmpl_var name=camera_nbr>" type="submit">Delete it</button>
              <br>
              <input type=text name="<tmpl_var name=camera_nbr>:camera_name" value="<tmpl_var name=camera_name>"><br>
              <!-- <input type=text name="<tmpl_var name=camera_nbr>:options" value="<tmpl_var name=options>"> -->
              <input type=checkbox name="<tmpl_var name=camera_nbr>:wan_access" value="checked" <tmpl_var name=wan_access>>External Access <br>
              <input type=checkbox name="<tmpl_var name=camera_nbr>:log_motion" value="on" <tmpl_var name=log_motion>>Log Motion<br>
              <label for="<tmpl_var name=camera_nbr>:rotate_image">Rotate:</label>
              <select name="<tmpl_var name=camera_nbr>:rotate_image">
                <option value="<tmpl_var name=rotate_image>" selected><tmpl_var name=rotate_image> Current
                <option value="0"> 0
                <option value="90"> 90
                <option value="180"> 180
                <option value="270"> 270
              </select><br>
              <label for="<tmpl_var name=camera_nbr>:resolution">Resolution:</label>
              <select name="<tmpl_var name=camera_nbr>:resolution">
                <option value="<tmpl_var name=resolution>" selected><tmpl_var name=resolution> Current
                <option value="640x480"> 640x480 VGA
                <option value="1280x720"> 1280x720
                <option value="1920x1080"> 1920x1080
                <option value="2304x1296"> 2304x1296
                <option value="3840x2160"> 3840x2160
              </select>
              </b>
            </td>
            <td align=left>
              <center>
               <!-- <b><tmpl_var name=server></b><br><br> -->
               <select name=<tmpl_var name=camera_nbr>:server>
                <tmpl_var name=servers>             
               </select><tmpl_var name=protocol>
               <br><b>Channel</b>
               <input type=text name="<tmpl_var name=camera_nbr>:channel" value="<tmpl_var name=channel>" size=2>
               <!--<b><tmpl_var name=protocol></b> -->
               
               </center>
            </td>
            <td align=center>
             <tmpl_unless name=readonly>
              <b>IP Address</b>
              <br>
              <input type=text <tmpl_var name=readonly> name="<tmpl_var name=camera_nbr>:ip_addr" value="<tmpl_var name=ip_addr>" size=13>
              <br>
             </tmpl_unless>
            <b>Port</b>
            <br>
              <input type=text <tmpl_var name=readonly> name="<tmpl_var name=camera_nbr>:port" value="<tmpl_var name=port>" size=15 title="blank for default">
              <br>
            </td>
            <td align=center>
              <b>ID</b>
              <br>
              <input type=text <tmpl_var name=readonly> name="<tmpl_var name=camera_nbr>:user" value="<tmpl_var name=user>">
              <br>
              <b>Password</b>
              <br>
              <input type=text <tmpl_var name=readonly> name="<tmpl_var name=camera_nbr>:password" value="<tmpl_var name=password>">
            </td>
            <td align=center>
             <table><tr><td>1</td><td>2</td><td>3</td></tr><tr><td>4</td><td>5</td><td>6</td></tr><tr><td>7</td><td>8</td><td>9</td></tr></td></table>
             <input type=text name="<tmpl_var name=camera_nbr>:motion_area_detect" value="<tmpl_var name=motion_area_detect>" size=10>
            </td>
          </tr>
          </tmpl_loop>
          <tr>
            <td align=left>
               <input type=submit name="state" value="Add">
            </td>
            <td align=left>
              <input type=text name="add_camera_name">
            </td>
            <td align=left>
             &nbsp;
            </td>
            <td align=left>
              &nbsp;
            </td>
            <td align=left>
              &nbsp;
            </td>
            <td align=left>
              &nbsp;
            </td>
          </tr>
        </table>
    </div></div>
<pre>
<tmpl_var name=email_string>
<tmpl_var name=login_comments>
</pre>
<!-- <tmpl_var name=login_comments> -->
</html>
EOF
return \$stuff;
}
sub restartMsg
{
my $stuff = <<EOF;
<html> <!-- restart -->
<tmpl_var name=form_action>
<tmpl_loop name=hidden>
  <input type=hidden name="<tmpl_var name=name>" value="<tmpl_var name=value>">
</tmpl_loop>
<tmpl_var name=menu>
<div class="body">
    <table class="tbody">
      <tr  class="alert">
       <th>
        Restarting ...
        <br><tmpl_var name=msg>
       </th>
      </tr>
    </table>
</div>
EOF
return \$stuff;
}

sub configuration
{
my $stuff = <<EOF;
<html>
<tmpl_var name=form_action>
<tmpl_loop name=hidden>
  <input type=hidden name="<tmpl_var name=name>" value="<tmpl_var name=value>">
</tmpl_loop>
<tmpl_var name=menu>
<div class="body">
    <table class="tbody">
      <tmpl_if name=msg>
       <tr class="alert">
        <th  colspan=100% ><tmpl_var name=msg></th>
       </tr>
      </tmpl_if>
      <tr  class="dark">
        <th align=center colspan=2>
         <font size=+1 color=green>Configuration values</font>
        </th>
      <tr  class="dark">
        <th colspan=2 align=left>
          <input type=submit name="state" value="Update">&nbsp;
           <input type=submit name="state" value="Restart" onClick="return confirm('are you sure?');">&nbsp;
           <input type=submit name="state" value="Check for updated software">
        </th>
      </tr>

      <!--
            <tr>
                <th>
                  Password
                </th>
                <td>
                  <tmpl_var name=passmsg><br>
                  <input type=password name="CONFIG:password" size=20>
                </td>
              </tr>
              <tr>
                <th>
                  Password again
                </th>
                <td>
                  <input type=password name="CONFIG:password_again" size=20>
                </td>
            </tr>
      -->
       <tr>
       <tr class="dark">
         <th colspan=2>
          <font color=green>CameraNet Network adapter</font>
         </th>
       </tr>
        <th>
          CameraNet IP
        </th>
        <td>
          <input name="CONFIG:cameraip" size=16 value="<tmpl_var name=cameraip>">
        </td>
      </tr>
      </tr>
        <th>
          CameraNet Subnet mask
        </th>
        <td>
          <input name="CONFIG:cameramask" size=16 value="<tmpl_var name=cameramask>">
        </td>
      </tr>
      <tr class="dark">
         <th colspan=2>
          <font color=green>Primary Network Adapter</font>
         </th>
      </tr>
      <tr>
        <th>
          LAN HTTP Port
        </th>
        <td>
          <input name="CONFIG:lanport" size=6 value="<tmpl_var name=lanport>">
          <br><tmpl_var name=dvrportmsg>
        </td>
      </tr>
      <tr>
        <th>
          WAN HTTP Port
        </th>
        <td>
          <input name="CONFIG:wanport" size=6 value="<tmpl_var name=wanport>">
        </td>
      </tr>
      <tr>
        <th>
          Connection Type
        </th>
        <td>
          <select name=CONFIG:contype title='If you change the IP address you will need to reboot'>
            <tmpl_if name=currcontype>
              <option value="<tmpl_var name=currcontype>"><tmpl_var name=currcontype>
            </tmpl_if>
            <option value="DHCP">DHCP
            <option value="STATIC IP">STATIC IP
          </select>
        </td>
      </tr>
      <tr>
        <th>
          Our IP
        </th>
        <td>
          <input name="CONFIG:ip" size=16 value="<tmpl_var name=currip>">
        </td>
      </tr>
      <tr>
        <th>
          Subnet Mask
        </th>
        <td>
          <input name="CONFIG:mask" size=16 value="<tmpl_var name=currmask>">
        </td>
      </tr>
      <tr>
        <th>
          Gateway
        </th>
        <td colspan=3>
          <input name="CONFIG:gw" size=16 value="<tmpl_var name=currgw>">
        </td>
      </tr>
      <tr>
        <th>
          Domain Name Server 1
        </th>
        <td>
          <input name="CONFIG:dns1" size=16 value="<tmpl_var name=dns1>">
        </td>
      </tr>
      <tr>
        <th>
          Domain Name Server 2
        </th>
        <td>
          <input name="CONFIG:dns2" size=16 value="<tmpl_var name=dns2>">
        </td>
      </tr>
      <tr>
        <th>
            user
        </th>
        <td>
          <input name="CONFIG:dvruser" size=16 value="<tmpl_var name=dvruser>">
          <br><tmpl_var name=dvrusermsg>
        </td>
      </tr>
      <tr>
        <th>
           Password
        </th>
        <td>
          <input name="CONFIG:dvrpass" size=16 value="<tmpl_var name=dvrpass>">
          <br><tmpl_var name=dvrpassmsg>
        </td>
      </tr>
      <tr class="dark">
        <th colspan=2><font color=green>Trusted IP's that can see all cameras</font></th>
      </tr>
      <tr>
        <th>
          <input type=submit name="state" value="Add Trusted IP">
        </th>
        <td>
          <input name="CONFIG:newtrustedip" size=16 value="">
        </td>
      </tr>
      <tmpl_loop name=trustedips>
       <tr>
        <td>
          <font size=+1  align=center>
            <b>
              <input type=submit name="state" value="Remove Trusted IP <tmpl_var name=rowid>">
            </b>
          <font>
        </td>
        <td>
          <tmpl_var name=ip>
        </td>
       </tr>
      </tmpl_loop>
      <tr>
      <td colspan=2 align=center>
       <table>
        <tr class="dark">
         <th colspan=3>
          <font color=green>System Load</font>
         </th>
        </tr>
        <tr  class="dark">
         <th>
           <font color=green>Last Minute</font>
        </th>
        <th>
          <font color=green>Five Minutes</font>
        </th>
        <th>
          <font color=green>Fifteen Minutes</font>
        </th>
       </tr>
       <tr>
        <th align=center>
         <tmpl_var name=min1>%
        </th>
        <th align=center>
         <tmpl_var name=min5>%
        </th>
        <th align=center>
         <tmpl_var name=min15>%
        </th>
        </tr>
        </table>
        </td>
        </tr>
    </table>
<div>

<pre>
<tmpl_var name=email_string>
<tmpl_var name=login_comments>
</pre>
<!-- <tmpl_var name=login_comments> -->
</font>
</form>
</body>
</html>
EOF
return \$stuff;
}

sub extern
{
my $stuff = <<EOF;
<html>
<!-- <tmpl_var name=msg> -->
<tmpl_var name=form_action>
<body>
<tmpl_var name=menu>
</body>
</html>
EOF
return \$stuff;
}
sub timezone
{
my $stuff = <<EOF;
<html>
<tmpl_var name=form_action>
<tmpl_loop name=hidden>
  <input type=hidden name="<tmpl_var name=name>" value="<tmpl_var name=value>">
</tmpl_loop>
<tmpl_var name=menu>
<div class="body">
    <table class="tbody">
      <tmpl_if name=msg>
       <tr class="alert">
        <th  colspan=100% ><tmpl_var name=msg></th>
       </tr>
      </tmpl_if>
    <tr class="dark">
     <td>
      &nbsp;
    <th halign=center>
     Timezones
    </th>
    <th>
     current date and time (24 Hour format)
    </th>
   <tr>
      <td halign=center>
        <input type=submit name="state" value="Set Timezone">
      </td>
    <td halign=center>
     <select name="timezone" id="timezone">
     <option value="<tmpl_var name=timezone>"><tmpl_var name=timezone>
     <tmpl_loop name=zones>
      <option value="<tmpl_var name=loc>"><tmpl_var name=loc></option>
     </tmpl_loop>
     </select>
    </td>
    <th halign=center>
        <tmpl_var name=day>-<tmpl_var name=month>-<tmpl_var name=year>
        &nbsp;
        <tmpl_var name=hour>:<tmpl_var name=minute>
    </th>
    </tr>
  </table>
<div>
</html>
EOF
return \$stuff;
}

sub motion_mask
{
my $stuff = <<EOF;
<!DOCTYPE html>
<html>
<head>
<style>
table {
    background: url(<tmpl_var name=jpeg>);
    background-size: <tmpl_var name=width>px <tmpl_var name=height>px;
    background-repeat: no-repeat;
    height: <tmpl_var name=height>px;
    width:  <tmpl_var name=width>px;
    border: 1px solid black;
    border-collapse: collapse;
}

td, tr { border: 1px solid black;}

</style>
</head>
<body>
<input type=hidden name="<tmpl_var name=camera_nbr>" value="<tmpl_var name=camera_name>">
<table>
  <tmpl_loop name=rows>
  <tr>
    <tmpl_loop name=columns>
    <td align=center><input type=checkbox name=cell_selected value='<tmpl_var name=cell_id>' <tmpl_var name=checked>></td>
    </tmpl_loop
  </tr>
  </tmpl_loop>
</table>

</body>
</html>
EOF
return \$stuff;
}

sub index_html
{
my $stuff = <<EOF;
<!DOCTYPE html>
<html>
<body>
<h1>basicNVR</h1>
<br>
<a href='/dvr'>NVR Viewer</a>
<br>
<!-- <a href='https://logout\@<tmpl_var name=ip_addr>'>Logout</a> -->
</body>
</html>
EOF
return \$stuff;
}


1;
