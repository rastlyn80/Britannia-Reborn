// SPDX-License-Identifier: GPL-3.0-or-later
using System.Text.Json;

static partial class Program {
 // Mountain relief (docs/MOUNTAINS.md): UO's impassable land (mountain rock,
 // cave walls, the void around dungeons) is drawn taller in 3D. Every terrain
 // corner surrounded on all four sides by impassable, dry land is lifted by
 // (factor-1) times its height above the nearest walkable corner, eased in over
 // the first `ramp` tiles. Corners touching walkable land keep their source
 // height, so movement, the server and walkable ground are unchanged.
 // Output beside the BRW chunks: relief.u8, one byte per corner (row-major,
 // width x height, units of 0.25 m), and relief.json describing it.
 // Sea cliffs over deep water would otherwise rise 60 m; mountains top out near 30.
 const float MaxLift=32f;
 static void ExportRelief(string[] args) {
  if(args.Length<2)throw new ArgumentException("relief DATASET_DIR [factor] [ramp]");
  string dataset=Path.GetFullPath(args[1]);
  double factor=args.Length>2?double.Parse(args[2],System.Globalization.CultureInfo.InvariantCulture):2.2;
  double ramp=args.Length>3?double.Parse(args[3],System.Globalization.CultureInfo.InvariantCulture):7.0;
  using var atlas=JsonDocument.Parse(File.ReadAllText(Path.Combine(dataset,"atlas.json")));
  var root=atlas.RootElement;
  int ox=root.GetProperty("originX").GetInt32(),oy=root.GetProperty("originY").GetInt32();
  int width=root.GetProperty("width").GetInt32(),height=root.GetProperty("height").GetInt32();
  double scale=root.GetProperty("elevationScale").GetDouble();
  var blocked=new bool[65536];
  foreach(var entry in root.GetProperty("landData").EnumerateObject()){
   ulong flags=entry.Value.GetProperty("flags").GetUInt64();
   blocked[int.Parse(entry.Name)]=(flags&0x40)!=0&&(flags&0x80)==0;
  }
  int count=width*height;
  var z=new sbyte[count];var solid=new bool[count];
  for(int cy=0;cy<height;cy+=64)for(int cx=0;cx<width;cx+=64){
   string file=Path.Combine(dataset,$"{ox+cx}_{oy+cy}.brw");
   if(!File.Exists(file))continue;
   var data=File.ReadAllBytes(file);
   for(int i=0;i<4096;i++){
    int x=cx+i%64,y=cy+i/64,o=24+i*3;
    if(x>=width||y>=height)continue;
    int id=data[o]|data[o+1]<<8;
    z[y*width+x]=(sbyte)data[o+2];solid[y*width+x]=blocked[id];
   }
  }
  // Corner (x,y) is shared by tiles (x-1..x, y-1..y), as in TerrainSurface.
  bool Inside(int x,int y){
   for(int dy=-1;dy<=0;dy++)for(int dx=-1;dx<=0;dx++){
    int tx=Math.Clamp(x+dx,0,width-1),ty=Math.Clamp(y+dy,0,height-1);
    if(!solid[ty*width+tx])return false;
   }
   return true;
  }
  // Two-pass chamfer distance to the nearest walkable corner, carrying its height.
  var distance=new float[count];var foot=new sbyte[count];
  for(int y=0;y<height;y++)for(int x=0;x<width;x++){int i=y*width+x;bool inner=Inside(x,y);distance[i]=inner?float.MaxValue:0f;foot[i]=z[i];}
  int[] fx={-1,0,1,-1},fy={-1,-1,-1,0},bx={1,0,-1,1},by={1,1,1,0};
  float[] cost={1.4142f,1f,1.4142f,1f};
  for(int pass=0;pass<2;pass++){
   for(int y=0;y<height;y++)for(int x=0;x<width;x++)Relax(x,y,fx,fy);
   for(int y=height-1;y>=0;y--)for(int x=width-1;x>=0;x--)Relax(x,y,bx,by);
  }
  void Relax(int x,int y,int[] ox2,int[] oy2){
   int i=y*width+x;if(distance[i]==0f)return;
   for(int k=0;k<4;k++){
    int nx=x+ox2[k],ny=y+oy2[k];if(nx<0||ny<0||nx>=width||ny>=height)continue;
    int n=ny*width+nx;float d=distance[n]+cost[k];
    if(d<distance[i]){distance[i]=d;foot[i]=foot[n];}
   }
  }
  var lift=new float[count];
  for(int i=0;i<count;i++){
   if(distance[i]==0f||distance[i]==float.MaxValue)continue;
   double t=Math.Clamp(distance[i]/ramp,0,1);t=t*t*(3-2*t);
   lift[i]=(float)((factor-1)*Math.Max(0,z[i]-foot[i])*scale*t);
  }
  // Soften single-corner spikes; walkable corners stay exactly at zero.
  var output=new byte[count];int lifted=0;float highest=0;
  for(int y=0;y<height;y++)for(int x=0;x<width;x++){
   int i=y*width+x;if(distance[i]==0f)continue;
   float sum=0;int n=0;
   for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++){int nx=x+dx,ny=y+dy;if(nx<0||ny<0||nx>=width||ny>=height)continue;sum+=lift[ny*width+nx];n++;}
   float value=0.5f*lift[i]+0.5f*sum/n;
   output[i]=(byte)Math.Clamp(Math.Round(Math.Min(value,MaxLift)/0.25),0,255);
   if(output[i]>0){lifted++;highest=Math.Max(highest,output[i]*0.25f);}
  }
  File.WriteAllBytes(Path.Combine(dataset,"relief.u8.tmp"),output);
  File.Move(Path.Combine(dataset,"relief.u8.tmp"),Path.Combine(dataset,"relief.u8"),true);
  var meta=new {schema=1,format="relief.u8",originX=ox,originY=oy,width,height,unitMeters=0.25,factor,ramp,lifted,highestMeters=highest};
  File.WriteAllText(Path.Combine(dataset,"relief.json"),JsonSerializer.Serialize(meta,Json));
  Console.WriteLine($"RELIEF: {lifted} corners lifted, highest +{highest:0.0} m (factor {factor}, ramp {ramp} tiles)");
 }
}
