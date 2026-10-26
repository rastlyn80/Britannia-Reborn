// SPDX-License-Identifier: GPL-3.0-or-later
using System.Text.Json;
using System.Security.Cryptography;

static partial class Program {
 // Engine-independent, little-endian BRW1 chunk IR. Coordinates/elevations,
 // graphic IDs and hues are exact. This is not a mesh or proprietary input copy.
 static void ExportAtlas(string[] args) {
  if(args.Length<3)throw new ArgumentException("atlas DATA_DIR OUTPUT_DIR [x y width height]");
  int x=args.Length>3?int.Parse(args[3]):0,y=args.Length>4?int.Parse(args[4]):0;
  int width=args.Length>5?int.Parse(args[5]):5120,height=args.Length>6?int.Parse(args[6]):4096;
  if(x<0||y<0||x%64!=0||y%64!=0||width<64||height<64||width%64!=0||height%64!=0||x+width>7168||y+height>4096)throw new ArgumentException("Atlas bounds must be 64-aligned inside Trammel");
  string output=Path.GetFullPath(args[2]);Directory.CreateDirectory(output);
  string source=File.Exists(Path.Combine(args[1],"map1.mul"))?"map1.mul":"map1LegacyMUL.uop";
  using var map=Read(Path.Combine(args[1],source));
  string sha=System.Convert.ToHexString(SHA256.HashData(map.BaseStream));
  File.WriteAllText(Path.Combine(output,"converting.lock"),"Conversion in progress; retry prepare-britannia if interrupted.");
  var land=new Dictionary<int,TileInfo>();var objects=new Dictionary<int,TileInfo>();
  var overview=new List<int[]>();var chunks=new List<object>();long staticCount=0;
  const int size=64;
  for(int cy=y;cy<y+height;cy+=size)for(int cx=x;cx<x+width;cx+=size){
   string name=$"{cx}_{cy}.brw",file=Path.Combine(output,name);
   var world=Convert(args[1],cx,cy,size,size,4096,false);
   foreach(var info in world.landData??new())land[info.Key]=info.Value;
   foreach(var info in world.staticData??new())objects[info.Key]=info.Value;
   var ordered=world.terrain.OrderBy(t=>t.y).ThenBy(t=>t.x).ToArray();
   using(var writer=new BinaryWriter(File.Create(file+".tmp"))){
    writer.Write(0x31575242u);writer.Write(cx);writer.Write(cy);writer.Write(size);writer.Write(size);writer.Write(world.statics.Length);
    foreach(var t in ordered){writer.Write((ushort)t.id);writer.Write((sbyte)t.z);}
    foreach(var s in world.statics){writer.Write((ushort)s.id);writer.Write((byte)(s.x-cx));writer.Write((byte)(s.y-cy));writer.Write((sbyte)s.z);writer.Write((ushort)s.hue);}
   }
   File.Move(file+".tmp",file,true);
   foreach(var t in ordered)if((t.x%8==0||t.x==x+width-1)&&(t.y%8==0||t.y==y+height-1))overview.Add(new[]{t.x,t.y,t.z,t.id});
   staticCount+=world.statics.Length;
   chunks.Add(new {x=cx,y=cy,file=name,statics=world.statics.Length});
   if(chunks.Count%64==0)Console.WriteLine($"ATLAS: {chunks.Count}/{width/64*(height/64)} chunks");
  }
  var inputs=Directory.EnumerateFiles(args[1]).Where(p=>new[]{source,"tiledata.mul","mapdifl1.mul","mapdif1.mul","stadifl1.mul","stadif1.mul","stadifi1.mul","staidx1.mul","statics1.mul"}.Contains(Path.GetFileName(p))).ToDictionary(p=>Path.GetFileName(p)!,p=>{using var f=Read(p);return System.Convert.ToHexString(SHA256.HashData(f.BaseStream));});
  var result=new {provenance=File.Exists(Path.Combine(args[1],"SYNTHETIC.txt"))?"SYNTHETIC fixture — not Britannia":"LOCAL TRAMMEL — base + local diffs",inputs,schema=1,format="BRW1",facet="Trammel",originX=x,originY=y,width,height,chunkSize=size,elevationScale=0.2,overviewStep=8,terrainCount=(long)width*height,staticCount,mapSha256=sha,source,landData=land,staticData=objects,chunks,overview};
  File.WriteAllText(Path.Combine(output,"atlas.json.tmp"),JsonSerializer.Serialize(result));
  File.Move(Path.Combine(output,"atlas.json.tmp"),Path.Combine(output,"atlas.json"),true);
  File.Delete(Path.Combine(output,"converting.lock"));
  Console.WriteLine($"ATLAS COMPLETE: {width}x{height}; {chunks.Count} chunks; {staticCount} statics; {objects.Count} IDs");
 }
}
