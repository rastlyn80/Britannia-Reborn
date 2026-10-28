"""Synthetic binary fixtures; no original client assets are needed."""
import importlib.util,struct,unittest,zlib
from io import BytesIO
from types import SimpleNamespace
from pathlib import Path
spec=importlib.util.spec_from_file_location('sequences',Path(__file__).with_name('uo-human-sequences.py'))
seq=importlib.util.module_from_spec(spec);spec.loader.exec_module(seq)

def archive(raw,compressed=True):
 packed=zlib.compress(raw) if compressed else raw
 return struct.pack('<IIIQII',0x0050594d,5,0,28,1,1)+struct.pack('<IQ',1,0)+struct.pack('<QIIIQIH',74,0,len(packed),len(raw),123,0,int(compressed))+packed

def sequence():
 # One extended human mode, one movement and one type/subaction choice.
 return struct.pack('<I',400)+bytes(48)+struct.pack('<II',0,1)+struct.pack('<BbI',0,-1,4)+struct.pack('<I',0)+struct.pack('<IBII',1,0,0,1)+struct.pack('<IbbIII',1,0,4,2,9,10)

class Sequences(unittest.TestCase):
 def inspect(self,raw,allowed={400}):
  path=SimpleNamespace(stat=lambda:SimpleNamespace(st_size=len(raw)),open=lambda mode:BytesIO(raw))
  return seq.inspect(path,allowed)
 def test_compressed_and_plain(self):
  for compressed in [True,False]:
   rows=self.inspect(archive(sequence(),compressed));self.assertEqual(len(rows),1)
   self.assertEqual(rows[0]['unparsed_bytes'],0)
   self.assertEqual(rows[0]['modes'][0]['new_protocol_actions'],[{'type':0,'subaction':4,'groups':[9,10]}])
 def test_excluded_family(self):self.assertEqual(self.inspect(archive(sequence()),{401}),[])
 def test_unknown_tail_stays_explicit(self):self.assertEqual(self.inspect(archive(sequence()+b'unknown'))[0]['unparsed_bytes'],7)
 def test_truncated_sequence_is_a_blocker(self):self.assertIn('parse_blocker',self.inspect(archive(sequence()[:-1]))[0])
 def test_invalid_directory(self):
  data=bytearray(archive(sequence()));struct.pack_into('<Q',data,12,len(data)+100)
  with self.assertRaises(ValueError):self.inspect(data)
 def test_invalid_payload_length(self):
  data=bytearray(archive(sequence()));struct.pack_into('<I',data,56,64*1024*1024+1)
  with self.assertRaises(ValueError):self.inspect(data)
 def test_truncated_payload(self):
  with self.assertRaises(ValueError):self.inspect(archive(sequence())[:-2])
 def test_wrong_signature(self):
  data=bytearray(archive(sequence()));data[0]=0
  with self.assertRaises(ValueError):self.inspect(data)

if __name__=='__main__':unittest.main()
