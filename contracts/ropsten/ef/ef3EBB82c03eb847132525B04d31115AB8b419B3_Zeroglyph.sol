//SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ZeroglyphArt {
    string public constant html = "<html><script>class O{constructor(){this.children=[];this.w=this.h=128;this.x=this.y=this.vx=this.vy=this.ax=this.ay=this.or=this.od=this.ov=0;this.strokeColor=this.fillColor=\"\";}update(){this.vx+=this.ax;this.x+=this.vx;this.vy+=this.ay;this.y+=this.vy;this.w+=this.vw;this.h+=this.vw;this.rad +=this.vw;function wrap(thing){if(thing.vx>0){if(thing.x>width){thing.x-=width;}}if(thing.vy>0){if(thing.y>height){thing.y-=height;}}if(thing.vx<0){if((thing.x+thing.w)<0){thing.x+=width;}}if(thing.vy<0){if((thing.y+thing.h)<0){thing.y+=height;}}};wrap(this);this.angle+=this.vangle;if(this.w<=(s/2+1)){paused=1;}for(c of this.children){c.update();}}draw(){save();function drawShape(x,y,ang,points){save();;let dx=x;let dy=y;translate(dx,dy);angle(ang);translate(-dx,-dy);$.beginPath();$.moveTo(x+points[0].x,y+points[0].y);for (let val of points){$.lineTo(x+val.x,y+val.y);}$.closePath();$.fill();$.stroke();restore();};function addPoint(radius,radians){let xx=radius*Math.cos(radians);let yy=radius*Math.sin(radians);p.push({x:xx,y:yy});};function addShape(sides){for(let i=0;i<=sides;i++){if(i==0){addPoint(rad,0);}else {addPoint(rad,2.0/sides*i*Math.PI);}};};function addStar(points){let sides=points*2;for(let i=0;i<=sides;i++){if(i==0){addPoint(rad,0);}else {var r=rad;if(i%2==1){r=rad/2;}addPoint(r,2.0/sides*i*Math.PI);}};};var rad=this.rad;var p=[];lineWidth(line_width);$.fillStyle= color1;$.strokeStyle= color2;var xx=this.w/2+this.x;var yy=this.h/2+this.y;this.od+=this.ov;if(this.od>360){this.od=this.od % 360;}xx+=this.or*Math.cos((Math.PI/180)*this.od);yy+=this.or*Math.sin((Math.PI/180)*this.od);let ang=this.angle;if(this.stellate){addStar(this.sides);}else{addShape(this.sides);}drawShape(xx,yy,ang,p);if(xx+this.w>width){drawShape(xx-width,yy,ang,p);}if(yy+this.h>height){drawShape(xx,yy-height,ang,p);}if(this.x-this.w<0){drawShape(xx+width,yy,ang,p);}if(this. y-this.h<0){drawShape(xx,yy+height,ang, p);}if(this.x-this.w<0){if(yy+this.h>height){drawShape(xx+width,yy-height,ang,p);}}if(xx+this.w>width){if(this.y-this.h<0){drawShape(xx-width,yy+height,ang,p);}}if(xx+this.w>width){if(yy+this.h>height){drawShape(xx-width,yy-height,ang,p);}}if(this.x-this.w<0){if(this.y-this.h<0){drawShape(xx+width,yy+height,ang,p);}}translate(this.x,this.y);for(c of this.children){c.draw();}restore();}}clearRect=(x,y,w,h)=>$.clearRect(x,y,w,h);rotate=(rad)=>$.rotate(rad);save=()=>$.save();restore=()=>$.restore();translate=(x,y)=>$.translate(x,y);strokeRect=(x,y,w,h)=>$.strokeRect(x,y,w,h);fillRect=(x,y,w,h)=>$.fillRect(x,y,w,h);fillText=(t,x,y)=>$.fillText(t,x,y);strokeText=(t,x,y)=>$.strokeText(t,x,y);fillStyle=(style)=>$.fillStyle=style;strokeStyle=(style)=>$.strokeStyle=style;angle=(degrees)=>rotate((Math.PI/180)*degrees);drawImage=(name,x,y)=>$.drawImage(name,x,y);stroke=()=>$.stroke();beginPath=()=>$.beginPath();arc=(x1,y1,x2,y2,rad,maybe)=>$.arc(x1,y1,x2,y2,rad,maybe);fillColor=(r,g,b,a)=>fillStyle('rgba('+r+','+g+','+b+','+a+')');strokeColor=(r,g,b,a)=>strokeStyle('rgba('+r+','+g+','+b+','+a+')');fillHSLA=(h,s,l,a)=>fillStyle('hsla('+h+','+s+','+l+','+a+')');strokeHSLA=(h,s,l,a)=>strokeStyle('hsla('+h+','+s+','+l+','+a+')');fillHex=(h)=>fillStyle(h);strokeHex=(h)=>strokeStyle(h);lineWidth=(w)=>$.lineWidth=w;function randomBool(){return (Math.random()<=0.5);}function random(amount){return (-1+Math.random()*2)*amount;}function randomInt(amount){return Math.floor(Math.random()*amount);}function clear(r,g,b,a){save();fillColor(r,g,b,a);fillRect(0,0,width,height);restore();}function clearHSV(hsva){save();$.fillStyle=hsva;fillRect(0,0,width,height);restore();}function font(f){$.font=f;}function text(t,x,y){strokeText(t,x,y);}function line(x,y,x2,y2){$.beginPath();$.moveTo(x,y);$.lineTo(x2,y2);$.stroke();}function triangle(x,y){$.beginPath();$.moveTo(x+175,y+150);$.lineTo(x+120,y+175);$.lineTo(x+120,y+125);$.lineTo(x+175,y+150);$.fill();$.stroke();}function circle(x,y,r,r){ellipse(x,y,r,r);}function ellipse(x,y,rx,ry){$.beginPath();$.ellipse(x,y,rx,ry,3.14/4,0,2*3.14);$.fill();$.stroke();}function curve(x1,y1,x2,y2,x3,y3){drawCurve(x1,y1,x2,y2,x3,y3);}function drawCurve(x1,y1,x2,y2,x3,y3){$.beginPath();$.moveTo(x1,y1);$.bezierCurveTo(x1,y1,x2,y2,x3,y3);$.stroke();};function spline(points){$.beginPath();$.moveTo(points[0].x,points[0].y);for (i=1;i<points.length-2;i ++);{var xc=(points[i].x+points[i+1].x)/2;var yc=(points[i].y+points[i+1].y)/2;$.quadraticCurveTo(points[i].x,points[i].y,xc,yc);}$.quadraticCurveTo(points[i].x,points[i].y,points[i+1].x,points[i+1].y);$.stroke();}function sizeToWindow(){$=document.getElementById('canvas');$.width=window.innerWidth;$.height=window.innerHeight;width=window.innerWidth;height=window.innerHeight;fullScreen=1;}function size(w,h){if(w==0||h==0){fullScreen=1;sizeToWindow();}else {fullScreen=0;$.width=w;$.height=h;width=w;height=h;}}function start(){$=document.getElementById('canvas');$.imageSmoothingQuality=\"high\";$.imageSmoothingEnabled=1;width=$.width;height=$.height;children.length=0;var min=window.innerWidth;if(window.innerHeight<min){min=window.innerHeight;}min=800;size(min,min);begin(width,height);loadObjects();window.addEventListener('resize',resize,false);window.requestAnimationFrame(update);}function shouldRender(){if(paused){if(increment){increment=0;return 1;}return 0;}return 1;}function update(){$=document.getElementById('canvas').getContext('2d');if(shouldRender()){degrees+=stride;if(degrees>=360){degrees-=360;}if(firstrun){$.fillStyle=color3;strokeColor(0,0,0,0.15);lineWidth(4);for(j=0;j<400;j++){let x=randomInt(width);let y=randomInt(height);let i=random(42);let j=random(42);if(bgStyle==1){let i=randomInt(42);let j=randomInt(42);strokeColor(0,0,0,0);ellipse(x,y,i,i);}if(bgStyle==0){let i=random(42);let j=random(142);strokeColor(255,255,255,0.015);line(x,y,x+i,y+j);}if(bgStyle==2){let i=random(42);let j=random(142);strokeColor(0,0,0,0.013);curve(x,y,x,y,x-100,y-40);}}}if(state==0){if(maxFrames>0 && currentFrame>maxFrames){paused=1;}else {clearHSV(color0);degrees+=deg;currentFrame=currentFrame+1;}}if(state==1){clearHSV(color0);degrees+=deg;currentFrame=currentFrame+1;}if(state==2){clearHSV(color0);degrees+=deg;currentFrame=currentFrame+1;}if(state==3){clearHSV(color0);degrees+=deg;currentFrame=currentFrame+1;}for(c of this.children){c.update();}for(c of this.children){c.draw();}}window.requestAnimationFrame(update);}function resize(){if(fullScreen){sizeToWindow();}};function messageNative(name){try{webkit.messageHandlers.callback.postMessage(name);}catch(err){console.log(err);}}keys=[];document.addEventListener('keydown',function(event){if(event.keyCode==37){keys[\"left\"]=1;}else if(event.keyCode==39){keys[\"right\"]=1;}});mouseX=0;mouseY=0;document.addEventListener('mousemove',(event)=> {mouseX=event.clientX;mouseY=event.clientY;});document.onmousedown=function(){switch(state){case 0:state=1;paused=0;break;case 1:state=2;for(obj of children){obj.vx=random(1);obj.vy=random(1);obj.or= random(1);obj.od= random(1);obj.or=random(1);obj.ov= random(1);obj.vangle= random(1);}break;case 2:state=3;clearObjects();$.fillStyle=color0;fillRect(0,0,width,height);break;case 3:state=0;loadObjects();currentFrame=0;break;}};document.addEventListener('keyup',function(event){if(event.keyCode==37){keys[\"left\"]=0;}else if(event.keyCode==39){keys[\"right\"]=0;}});fullScreen=1;width=0;height=0;children=[];paused=0;increment=0;degrees=0;stride=1;function styleBlack(){color0='rgba(0,0,0,0.05)';color1='rgba(180,180,180,0.03)';color2='rgba(225,225,225,1)';color3='rgba(255,255,255,0.002)';}function styleWhite(){color0='rgba(255,255,255,0.05)';color1='rgba(180,180,180,0.02)';color2='rgba(60,60,60,1)';color3='rgba(0,0,0,0.002)';}function styleRandom(){r0=randomInt(100);g0=randomInt(100);b0=randomInt(100);a0=0.05;r=randomInt(255);g=randomInt(255);b=randomInt(255);a=0.01;r2=100+randomInt(155);g2=100+randomInt(155);b2=100+randomInt(155);a2=1;color0='rgba('+r0+','+g0+','+b0+','+a0+')';color1='rgba('+r+','+g+','+b+','+a+')';color2='rgba('+r2+','+g2+','+b2+','+a2+')';if(r0+g0+b0>150){color3='rgba(0,0,0,0.02)';}else {color3='rgba(255,255,255,0.002)';}}function styleRandom2(){r2=randomInt(80);g2=randomInt(80);b2=randomInt(80);a2=1;r=randomInt(255);g=randomInt(255);b=randomInt(255);a=0.01;r0=100+randomInt(155);g0=100+randomInt(155);b0=100+randomInt(155);a0= 0.05;color0='rgba('+r0+','+g0+','+b0+','+a0+')';color1='rgba('+r+','+g+','+b+','+a+')';color2='rgba('+r2+','+g2+','+b2+','+a2+')';color3='rgba(0,0,0,0.01)';}function styleHue(){hue1=randomInt(360);hue2=(hue1+120)% 360;hue3=(hue1+240)% 360;color0='HSLA('+hue2+',25%,60%,0.1)';color1='HSLA('+hue1+',50%,50%,0.05)';color2='HSLA('+hue3+',50%,20%,1)';color3='rgba(0,0,0,0.01)';}function styleHue2(){hue0=randomInt(360);hue1=(hue0+120)% 360;hue2=(hue0+240)% 360;color0='HSLA('+hue0+',25%,20%,0.1)';color1='HSLA('+hue1+',100%,50%,0.025)';color2='HSLA('+hue2+',80%,60%,1)';color3='rgba(255,255,255,0.002)';}function clearObjects(){children=[];$.fillStyle=color0;clearHSV(color0);}var inputs=[];firstrun=1;inputs[0]= randomInt(4);inputs[1]= randomInt(6);inputs[2]= randomInt(6);inputs[3]= randomInt(5);inputs[4]= randomInt(5);inputs[5]= 2+ Math.random()*4;inputs[6]= Math.floor(random(3));inputs[7]= Math.floor(random(3));inputs[8]= Math.floor(random(3));inputs[9]= Math.floor(random(3));inputs[10]= 1+randomInt(5);inputs[11]= 0;inputs[12]= random(3);inputs[13]= randomInt(6);inputs[14]= randomInt(6);inputs[15]= randomInt(3);inputs[16]= randomBool();inputs[17]= Math.floor(2+random(9));state=0;function begin(width,height){bgStyle=inputs[0];rows=inputs[1];cols=inputs[2];if(rows==0 && cols==0){rows=8;cols=8;}maxHeight=height/rows;maxWidth=width/cols;s=maxWidth;if(s>maxWidth){s=maxWidth;}if(s>maxHeight){s=maxHeight;}s=s/(1+randomInt(3));if(s<100 ){s=100;}w=s;h=s;sides=inputs[5];randoSides=1;vw=0;vx=inputs[6];vy=inputs[7];if(vx==0 && vy ==0){vx=inputs[8];vy=inputs[9];}ang=0;deg=0;line_width=inputs[10];dang=inputs[11];vangle=inputs[12];if(randomBool()){vangle=0;}currentFrame=0;maxFrames=30;dx=-(maxFrames*vx)+vx*maxFrames/2;dy=-(maxFrames*vy)+vy*maxFrames/2;altRow=0;altCol=0;if(randomBool()){altRow=randomBool();altCol=randomBool();}style=inputs[13];if(style==0){styleBlack();}if(style==1){styleWhite();}if(style==2){styleRandom();}if(style==3){styleRandom2();}if(style==4){styleHue2();}if(style==5){styleHue();}if(style==6){styleBlack();}x=width/2-(s/2*cols)+dx;y=height/2-(s/2*rows)+dy;if(rows==0){rows=height/s;y=0;}if(cols==0){cols= width/s;x=0;}if(randomBool()){if(sides>=2){dang=-45;}}or=0;od=0;ov=0;if(randomBool()){or=inputs[14];ov =inputs[15];if(randomBool()){ov=ov*-1;}}}function loadObject(i,j){obj=new O();children.push(obj);if(sides==0){obj.sides=inputs[17];}else{;if(randoSides){   obj.sides=2+Math.random()*sides;if(inputs[16]||Math.random()>0.3){obj.sides=Math.floor(obj.sides);}}else {obj.sides=sides;}}   ;;obj.angle=ang;if(randomBool()){obj.angle=90;}obj.angle+=dang;obj.vangle=random(vangle);;let offsetX=0;let offsetY=0;if(altRow && altCol){if(randomBool){offsetX=-w/4;offsetX+=(i % 2)*w/2;}else{offsetY=-h/4;offsetY+=(j % 2)*h/2;}}else{if(altRow){offsetX=-w/4;offsetX+=(i % 2)*w/2;};if(altCol){offsetY=-h/4;offsetY+=(j % 2)*h/2;};}obj.x=x+j*s+offsetX;obj.y=y+i*s+offsetY;obj.w=w;obj.h=h;obj.vw=0;obj.rad=w/2;obj.vx=vx;obj.vy=vy;obj.stellate=(Math.random()<=0.01);if(randomBool()){obj.or=or;obj.od=0;obj.ov=ov;};if(vx==0 && vy ==0){ obj.vx=random(1);obj.vy=random(1);}if(Math.random()<=0.02){if(randomBool()){  obj.vx=random(obj.vx);};if(randomBool()){obj.vy=random(obj.vy);}}}function loadObjects(){for(j=0;j<cols;j++){for(i=0;i<rows;i++){loadObject(i,j);}}}</script><body onload=\"start();\" style= \"background-color:rgba(100,100,100,1);height:100%;border:0px;\"><div id=\"container\" style= \"position: absolute;top:0%;left:0%;-webkit-user-select: none;border:0px;\" ><canvas id=\"canvas\" style= \"position: absolute;top:0%;left:0%;border:0px;\"></canvas></div></body></html>";
    address public artist;
    constructor(){artist = msg.sender;}
}

contract Zeroglyph is ERC721URIStorage, Ownable {

   ZeroglyphArt public art;

   string public uri = "seano.art/zeroglyph/";
   uint256 public price = 1;
   uint256 public royalty = 7;

    // these could be computed
    // not sure which is better
   uint256 public constant maxEdition = 100;

   uint256 private seriesLimit = 0;
   uint256 public constant maxSeries = 100; 
    
   mapping(uint256 => uint256) public timestamps;
   mapping(uint256 => uint256) public blocknumbers;
   mapping(uint256 => string) public inputs;
      
   mapping(address => bool) public excludedList;

   using Counters for Counters.Counter;
   Counters.Counter private _tokenIds;

   event UpdatedURI(string oldURI, string newURI);

   constructor(address _art) ERC721("Zeroglyph", "ZZZ"){
      art = ZeroglyphArt(_art);   
      excludedList[art.artist()] = true;
   }

   function releaseNextSeries() public onlyOwner {
      seriesLimit++;
   }

   function tokensIssued() public view returns (uint256) {
      return _tokenIds.current();
   }

   function html() public view returns (string memory){
      return art.html();
   }

   function mint(address recipient, string memory tokenURI) public onlyOwner returns (uint256){
      require (_tokenIds.current() < maxEdition);
        
      // if < seriesMax
      // if < editionMax
      // if less than 

      _tokenIds.increment();

      uint256 newItemId = _tokenIds.current();
      _mint(recipient, newItemId);

      string memory itemId = uint2str(newItemId);
      _setTokenURI(newItemId, string(abi.encodePacked(tokenURI, itemId)));
  
      timestamps[newItemId] = block.timestamp;
      blocknumbers[newItemId] = block.number;
        
      inputs[newItemId] = uint2str(block.timestamp);
      return newItemId;
   }

   function input(uint256 index) public view returns (string memory) {
      string memory inp = inputs[index];
      return string(abi.encodePacked("<script>input = '", inp, "';</script>"));
   }
    
    
   function buyToken() public payable {
      mint(msg.sender, uri);
      //transfer ether to wallet
      payable(art.artist()).transfer(msg.value);
   }
    
   function setURI(string memory _uri) public {
      string memory olduri = uri;
      uri = _uri;
      emit UpdatedURI(olduri, uri);
   }

   function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
      if (_i == 0) {
         return "0";
      }
        
      uint j = _i;
      uint len;
      while (j != 0) {
         len++;
         j /= 10;
      }
      bytes memory bstr = new bytes(len);
      uint k = len;
      while (_i != 0) {
         k = k-1;
         uint8 temp = (48 + uint8(_i - _i / 10 * 10));
         bytes1 b1 = bytes1(temp);
         bstr[k] = b1;
         _i /= 10;
      }
      return string(bstr);
   }

}