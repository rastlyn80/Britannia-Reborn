using System.IO.Compression;
using System.Text.Json;

// Local read-only artwork adapter. Outputs are proprietary derivatives and
// belong only in ignored *.local.json files, never in the published project.
static class GumpArt
{
 public static void Export(string directory,string output,int[] ids)
 {
  var archive=Path.Combine(directory,"gumpartLegacyMUL.uop");
  using var reader=new BinaryReader(File.OpenRead(File.Exists(archive)?archive:Path.Combine(directory,"gumpart.mul")));
  var records=new List<object>();
  var index=new Dictionary<ulong,(long offset,int packed,int raw,ushort flag)>();
  if(File.Exists(archive))
  {
   if(reader.ReadUInt32()!=0x0050594d) throw new InvalidDataException("Gump UOP signature");
   reader.ReadUInt32();reader.ReadUInt32();long next=reader.ReadInt64();var seen=new HashSet<long>();
   while(next!=0)
   {
    if(!seen.Add(next)||next<0||next>reader.BaseStream.Length-12) throw new InvalidDataException("Gump directory");
    reader.BaseStream.Position=next;int count=reader.ReadInt32();next=reader.ReadInt64();
    if(count<0||count>100000) throw new InvalidDataException("Gump count");
    for(int i=0;i<count;i++)
    {
     long offset=reader.ReadInt64();int header=reader.ReadInt32(),packed=reader.ReadInt32(),raw=reader.ReadInt32();ulong hash=reader.ReadUInt64();reader.ReadUInt32();ushort flag=reader.ReadUInt16();
     if(offset!=0) index[hash]=(checked(offset+header),packed,raw,flag);
    }
   }
  }
  foreach(int id in ids.Distinct())
  {
   byte[] raw;int width,height;
   if(File.Exists(archive))
   {
    if(!index.TryGetValue(Program.Hash($"build/gumpartlegacymul/{id:D8}.tga"),out var entry)) continue;
    if(entry.offset<0||entry.packed<8||entry.raw<8||entry.raw>67108864||entry.offset>reader.BaseStream.Length-entry.packed||entry.flag>1) throw new InvalidDataException("Gump entry bounds/compression");
    reader.BaseStream.Position=entry.offset;raw=reader.ReadBytes(entry.packed);
    if(entry.flag==1)
    {
     // Gump UOP dimensions precede its zlib stream; compressed entries also
     // include dimensions in the expanded payload (native client convention).
     using var stream=new ZLibStream(new MemoryStream(raw,8,raw.Length-8),CompressionMode.Decompress);
     raw=new byte[entry.raw];stream.ReadExactly(raw);
     if(stream.ReadByte()!=-1) throw new InvalidDataException("Expanded gump overflow");
    }
    width=BitConverter.ToInt32(raw,0);height=BitConverter.ToInt32(raw,4);raw=raw[8..];
   }
   else
   {
    using var lookup=new BinaryReader(File.OpenRead(Path.Combine(directory,"gumpidx.mul")));
    if(id<0||(long)id*12>lookup.BaseStream.Length-12) continue;
    lookup.BaseStream.Position=(long)id*12;int offset=lookup.ReadInt32(),length=lookup.ReadInt32(),extra=lookup.ReadInt32();
    if(offset<0||length<=0) continue;
    if(length>67108864||offset>reader.BaseStream.Length-length) throw new InvalidDataException("Gump MUL bounds");
    width=(extra>>16)&65535;height=extra&65535;reader.BaseStream.Position=offset;raw=reader.ReadBytes(length);
   }
   records.Add(new{id,width,height,rgba=System.Convert.ToBase64String(Decode(raw,width,height))});
  }
  File.WriteAllText(output,JsonSerializer.Serialize(records));
  Console.WriteLine($"LOCAL ARTWORK ONLY: {records.Count} gump images decoded");
 }
 internal static byte[] Decode(byte[] raw,int width,int height)
 {
  if(width<1||height<1||width>4096||height>4096||(long)width*height>16777216||raw.Length<height*4) throw new InvalidDataException("Gump dimensions");
  var rgba=new byte[checked(width*height*4)];using var rows=new BinaryReader(new MemoryStream(raw));
  for(int y=0;y<height;y++)
  {
   rows.BaseStream.Position=y*4;long offset=rows.ReadUInt32()*4L;
   if(offset<height*4||offset>raw.Length-4) throw new InvalidDataException("Gump row offset");
   rows.BaseStream.Position=offset;int x=0;
   while(x<width)
   {
    int color=rows.ReadUInt16(),run=rows.ReadUInt16();
    if(run<1||run>width-x) throw new InvalidDataException("Gump row run");
    for(int n=0;n<run;n++,x++)
    {
     if(color==0) continue;
     int pixel=(y*width+x)*4;rgba[pixel]=(byte)(((color>>10)&31)*255/31);rgba[pixel+1]=(byte)(((color>>5)&31)*255/31);rgba[pixel+2]=(byte)((color&31)*255/31);rgba[pixel+3]=255;
    }
   }
  }
  return rgba;
 }
}
