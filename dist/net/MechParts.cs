// The Mech's own parts (docs/MECH_CLASS.md, phase 3), built on this PC at install: the release
// carries RevNetMech.template (the parts with their animation frames left empty) and
// RevNetMech.bindings.json (each part's three anchor vertices on the game body and its shape
// around them); the frames come from this game's own body (DeusExCharacters.u). The release
// holds none of the game's data. Same steps as tools/mech_art.py fill. C# 5 (Windows
// PowerShell's Add-Type), no other libraries.
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Web.Script.Serialization;

public static class MechParts
{
	public static string LastError;   // the last failure in full (for the install log)

	class Package
	{
		public byte[] D;
		public int Version;
		public string[] Names;
		public List<string> ExportNames = new List<string>();
		public List<int> ExportOffsets = new List<int>();
		public int P;

		public Package(string path)
		{
			D = File.ReadAllBytes(path);
			P = 0;
			if (U32() != 0x9E2A83C1) throw new Exception(Path.GetFileName(path) + " is not an Unreal package");
			Version = D[4] | (D[5] << 8);
			P = 12;
			int nc = I32(), no = I32(), ec = I32(), eo = I32();
			Names = new string[nc];
			P = no;
			for (int i = 0; i < nc; i++)
			{
				if (Version >= 64)
				{
					int n = CI();
					Names[i] = System.Text.Encoding.GetEncoding(28591).GetString(D, P, Math.Max(0, n - 1));
					P += n;
				}
				else
				{
					int e = Array.IndexOf(D, (byte)0, P);
					Names[i] = System.Text.Encoding.GetEncoding(28591).GetString(D, P, e - P);
					P = e + 1;
				}
				P += 4;
			}
			P = eo;
			for (int i = 0; i < ec; i++)
			{
				CI(); CI(); I32();
				string name = Names[CI()];
				I32();
				int size = CI();
				int off = size > 0 ? CI() : 0;
				ExportNames.Add(name);
				ExportOffsets.Add(off);
			}
		}

		public int U16() { int v = BitConverter.ToUInt16(D, P); P += 2; return v; }
		public uint U32() { uint v = BitConverter.ToUInt32(D, P); P += 4; return v; }
		public int I32() { int v = BitConverter.ToInt32(D, P); P += 4; return v; }
		public float F32() { float v = BitConverter.ToSingle(D, P); P += 4; return v; }
		public int CI()
		{
			int b = D[P++];
			bool neg = (b & 0x80) != 0;
			int v = b & 0x3F;
			if ((b & 0x40) != 0)
			{
				int shift = 6;
				do { b = D[P++]; v |= (b & 0x7F) << shift; shift += 7; } while ((b & 0x80) != 0);
			}
			return neg ? -v : v;
		}

		void SkipProps()
		{
			while (true)
			{
				if (Names[CI()] == "None") return;
				int info = D[P++];
				int type = info & 0x0F, sc = (info >> 4) & 7;
				if (type == 10) CI();
				int size;
				if (sc == 0) size = 1; else if (sc == 1) size = 2; else if (sc == 2) size = 4; else if (sc == 3) size = 12;
				else if (sc == 4) size = 16; else if (sc == 5) size = D[P++];
				else if (sc == 6) { size = BitConverter.ToUInt16(D, P); P += 2; } else size = I32();
				if ((info & 0x80) != 0 && type != 3)
				{
					int b = D[P++];
					if ((b & 0x80) != 0) P += (b & 0x40) == 0 ? 1 : 3;
				}
				P += size;
			}
		}

		int Lazy() { if (Version > 61) I32(); return CI(); }

		// A Mesh or LodMesh export: where its vertices and triangles are, and the values after them; with
		// lod, a LodMesh's faces, wedges and materials too (the body's).
		public Mesh ReadMesh(string name, bool lod = false)
		{
			int k = ExportNames.FindIndex(n => string.Equals(n, name, StringComparison.OrdinalIgnoreCase));
			if (k < 0) throw new Exception("no " + name + " in the package");
			Mesh m = new Mesh();
			P = ExportOffsets[k];
			SkipProps();
			P += 41;
			m.VertsCount = Lazy();
			m.VertsOffset = P;
			P += m.VertsCount * 8;
			m.TrisCount = Lazy();                                  // Tris
			m.TrisOffset = P;
			P += m.TrisCount * 20;
			int cnt;
			int seqs = CI();
			for (int i = 0; i < seqs; i++)
			{
				CI(); CI(); I32(); I32();
				int notifies = CI();
				for (int j = 0; j < notifies; j++) { F32(); CI(); }
				F32();
			}
			cnt = Lazy(); P += cnt * 8;                            // Connects
			P += 41;
			cnt = Lazy(); P += cnt * 4;                            // VertLinks
			int tex = CI();
			for (int i = 0; i < tex; i++) CI();
			cnt = CI(); P += cnt * 25;                             // BoundingBoxes
			cnt = CI(); P += cnt * 16;                             // BoundingSpheres
			m.FrameVerts = I32();
			m.Frames = I32();
			I32(); I32();
			m.Scale = new double[] { F32(), F32(), F32() };
			m.Origin = new double[] { F32(), F32(), F32() };
			if (!lod) return m;
			I32(); I32(); I32();                                   // RotOrigin
			I32(); I32();                                          // CurPoly, CurVertex
			if (Version == 65) F32();
			else if (Version >= 66) { cnt = CI(); P += cnt * 4; }  // TextureLOD
			cnt = CI(); P += cnt * 2;                              // CollapsePointThus
			cnt = CI(); P += cnt * 2;                              // FaceLevel
			cnt = CI();
			m.Faces = new int[cnt, 4];
			for (int i = 0; i < cnt; i++) for (int j = 0; j < 4; j++) m.Faces[i, j] = U16();
			cnt = CI(); P += cnt * 2;                              // CollapseWedgeThus
			cnt = CI();
			m.Wedges = new int[cnt, 3];
			for (int i = 0; i < cnt; i++) { m.Wedges[i, 0] = U16(); m.Wedges[i, 1] = D[P++]; m.Wedges[i, 2] = D[P++]; }
			cnt = CI();
			m.MatTex = new int[cnt];
			for (int i = 0; i < cnt; i++) { U32(); m.MatTex[i] = I32(); }
			cnt = CI(); P += cnt * 8;                              // SpecialFaces
			I32();                                                 // ModelVerts
			m.SpecialVerts = I32();
			return m;
		}
	}

	class Mesh
	{
		public int VertsCount, VertsOffset, TrisCount, TrisOffset, FrameVerts, Frames, SpecialVerts;
		public double[] Scale, Origin;
		public int[,] Faces, Wedges;     // (a LodMesh's) wedges per face and its material; vertex and UV per wedge
		public int[] MatTex;             // each material's skin
	}

	static double D(object o) { return Convert.ToDouble(o, System.Globalization.CultureInfo.InvariantCulture); }

	static double[] Norm(double[] v)
	{
		double l = Math.Sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
		return new double[] { v[0] / l, v[1] / l, v[2] / l };
	}

	static double[] Cross(double[] a, double[] b)
	{
		return new double[] { a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0] };
	}

	// Builds outPath from the template; returns null, or why it couldn't.
	public static string Build(string bodyPackage, string templatePath, string bindingsPath, string outPath)
	{
		try
		{
			var js = new JavaScriptSerializer();
			js.MaxJsonLength = int.MaxValue;
			var B = (Dictionary<string, object>)js.DeserializeObject(File.ReadAllText(bindingsPath));
			var body = new Package(bodyPackage);
			Mesh bm = body.ReadMesh((string)B["body"], true);
			var bs = (object[])B["scale"];
			var bo = (object[])B["origin"];
			if (bm.FrameVerts != Convert.ToInt32(B["frame_verts"]) || bm.Frames != Convert.ToInt32(B["frames"])
				|| bm.VertsCount != bm.FrameVerts * bm.Frames)
				return "this game's " + B["body"] + " has other animations than the one the parts were made for";
			for (int a = 0; a < 3; a++)
				if (bm.Scale[a] != D(bs[a]) || bm.Origin[a] != D(bo[a]))
					return "this game's " + B["body"] + " is scaled differently from the one the parts were made for";
			// The body's frames in game units.
			int nf = bm.Frames, fv = bm.FrameVerts;
			double[,,] F = new double[nf, fv, 3];
			for (int f = 0; f < nf; f++)
				for (int v = 0; v < fv; v++)
					for (int a = 0; a < 3; a++)
					{
						int raw = BitConverter.ToInt16(body.D, bm.VertsOffset + (f * fv + v) * 8 + a * 2);
						F[f, v, a] = (raw - bm.Origin[a]) * bm.Scale[a];
					}
			var tpl = new Package(templatePath);
			byte[] outData = (byte[])tpl.D.Clone();
			var meshes = (Dictionary<string, object>)B["meshes"];
			foreach (var kv in meshes)
			{
				var mb = (Dictionary<string, object>)kv.Value;
				int nv = Convert.ToInt32(mb["verts"]);
				Mesh tm = tpl.ReadMesh(kv.Key);
				if (tm.VertsCount != nf * nv)
					return "the template's " + kv.Key + " doesn't match its bindings";
				foreach (object po in (object[])mb["parts"])
				{
					var part = (Dictionary<string, object>)po;
					var an = (object[])part["anchors"];
					int i = Convert.ToInt32(an[0]), j = Convert.ToInt32(an[1]), k = Convert.ToInt32(an[2]);
					int first = Convert.ToInt32(part["first"]);
					var local = (object[])part["local"];
					for (int f = 0; f < nf; f++)
					{
						double[] A = { F[f, i, 0], F[f, i, 1], F[f, i, 2] };
						double[] AB = { F[f, j, 0] - A[0], F[f, j, 1] - A[1], F[f, j, 2] - A[2] };
						double[] AC = { F[f, k, 0] - A[0], F[f, k, 1] - A[1], F[f, k, 2] - A[2] };
						double[] e1 = Norm(AB), n = Norm(Cross(AB, AC)), e2 = Cross(n, e1);
						for (int q = 0; q < local.Length; q++)
						{
							var l = (object[])local[q];
							double l0 = D(l[0]), l1 = D(l[1]), l2 = D(l[2]);
							int at = tm.VertsOffset + (f * nv + first + q) * 8;
							for (int a = 0; a < 3; a++)
							{
								double g = A[a] + (l0 * e1[a] + l1 * e2[a] + l2 * n[a]);
								double r = Math.Round(g / bm.Scale[a] + bm.Origin[a]);
								short s = (short)Math.Max(-32768, Math.Min(32767, r));
								outData[at + a * 2] = (byte)(s & 0xFF);
								outData[at + a * 2 + 1] = (byte)((s >> 8) & 0xFF);
							}
							outData[at + 6] = 0;
							outData[at + 7] = 0;
						}
					}
				}
			}
			if (B.ContainsKey("arm"))
			{
				string why = FillArm((Dictionary<string, object>)B["arm"], bm, F, tpl, outData);
				if (why != null) return why;
			}
			File.WriteAllBytes(outPath, outData);
			return null;
		}
		catch (Exception e)
		{
			LastError = e.ToString();
			return e.Message;
		}
	}

	// The Mech's own arms in its view (StormArm): its triangles are the body's faces (each corner's vertex
	// and UV from its wedge, the face's skin), its frames frame A["frame"]'s vertices through each frame's
	// maps. Same steps as tools/mech_art.py fill_arm (its bytes must match).
	static string FillArm(Dictionary<string, object> A, Mesh bm, double[,,] F, Package tpl, byte[] outData)
	{
		string name = (string)A["mesh"];
		Mesh tm = tpl.ReadMesh(name);
		var verts = (object[])A["verts"];
		var groups = (object[])A["groups"];
		var faces = (object[])A["faces"];
		var xforms = (object[])A["xforms"];
		int nv = verts.Length, nf = xforms.Length, frame = Convert.ToInt32(A["frame"]);
		if (tm.TrisCount != faces.Length || tm.VertsCount != nf * nv)
			return "the template's " + name + " doesn't match its bindings";
		var index = new Dictionary<int, int>();
		for (int i = 0; i < nv; i++) index[Convert.ToInt32(verts[i])] = i;
		for (int t = 0; t < faces.Length; t++)
		{
			int fi = Convert.ToInt32(faces[t]);
			int at = tm.TrisOffset + t * 20;
			for (int c = 0; c < 3; c++)
			{
				int w = bm.Faces[fi, c];
				int v = index[bm.Wedges[w, 0] + bm.SpecialVerts];
				outData[at + c * 2] = (byte)(v & 0xFF);
				outData[at + c * 2 + 1] = (byte)((v >> 8) & 0xFF);
				outData[at + 6 + c * 2] = (byte)bm.Wedges[w, 1];
				outData[at + 7 + c * 2] = (byte)bm.Wedges[w, 2];
			}
			for (int b = 12; b < 16; b++) outData[at + b] = 0;     // PolyFlags
			Array.Copy(BitConverter.GetBytes(bm.MatTex[bm.Faces[fi, 3]]), 0, outData, at + 16, 4);
		}
		for (int f = 0; f < nf; f++)
		{
			var per = (object[])xforms[f];
			for (int q = 0; q < nv; q++)
			{
				var M = (object[])per[Convert.ToInt32(groups[q])];
				int v = Convert.ToInt32(verts[q]);
				double x = F[frame, v, 0], y = F[frame, v, 1], z = F[frame, v, 2];
				int at = tm.VertsOffset + (f * nv + q) * 8;
				for (int a = 0; a < 3; a++)
				{
					double pos = ((D(M[4 * a]) * x + D(M[4 * a + 1]) * y) + D(M[4 * a + 2]) * z) + D(M[4 * a + 3]);
					double r = Math.Round(pos * 256);
					short s = (short)Math.Max(-32768, Math.Min(32767, r));
					outData[at + a * 2] = (byte)(s & 0xFF);
					outData[at + a * 2 + 1] = (byte)((s >> 8) & 0xFF);
				}
				outData[at + 6] = 0;
				outData[at + 7] = 0;
			}
		}
		return null;
	}
}
