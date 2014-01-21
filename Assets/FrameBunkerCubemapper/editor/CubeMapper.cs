// CubeMapMaker (unfinished)
// original source: http://framebunker.com/blog/wp-content/uploads/2013/08/Static_Sky_Unite-presentation.pdf

using UnityEditor;
using UnityEngine;

public class CubeMapper : ScriptableWizard {

	public Cubemap cubeMap;
	public Camera targetCam;
	public Mesh outsideCubeMesh;

	Vector3[] kCubemapOrthoBases = {
		new Vector3( 0, 0,-1), new Vector3( 0,-1, 0), new Vector3(-1, 0, 0),
		new Vector3( 0, 0, 1), new Vector3( 0,-1, 0), new Vector3( 1, 0, 0),
		new Vector3( 1, 0, 0), new Vector3( 0, 0, 1), new Vector3( 0,-1, 0),
		new Vector3( 1, 0, 0), new Vector3( 0, 0,-1), new Vector3( 0, 1, 0),
		new Vector3( 1, 0, 0), new Vector3( 0,-1, 0), new Vector3( 0, 0,-1),
		new Vector3(-1, 0, 0), new Vector3( 0,-1, 0), new Vector3( 0, 0, 1),
	};
	

	[MenuItem ("Test/Cubemapper")]
	static void CreateWizard () {
		ScriptableWizard.DisplayWizard<CubeMapper>("Create cubemap", "Create");
	}


	void OnWizardCreate () {

		RenderToCubeMap(cubeMap,targetCam);

	}  


	void OnWizardUpdate () {
		//helpString = "Please set the color of the light!";
	}   


	void RenderToCubeMap(Cubemap dest, Camera cam)
	{
		// get MIP level 0 to be pure reflection
		/*
		for (int i=0;i<6;i++)
		{
			BeginCubeFaceRender(dest, (CubemapFace)i, 0, cam);
			cam.Render();
			EndCubeFaceRender(dest, (CubemapFace)i, 0, cam, false);
		}*/

		dest.Apply(false);

		// blur each mip level
		Material blurMaterial = new Material(Shader.Find("Custom/MirrorBlurCubemap"));
		blurMaterial.SetTexture("MyCube", dest);
		for (int mip=1; (dest.width>>mip)>0;mip++)
		{
			//specular[mip]
			//			blurMaterial.SetFloat("_SpecPwr", specular[mip]); // FIXME what is specular[mip]?
			blurMaterial.SetFloat("_SpecPwr", mip*8);

			// blur each face by rendering a cube that does a tons of samples
			for (int i=0; i<6; i++)
			{
				BeginCubeFaceRender(dest, (CubemapFace)i, mip, cam);
				// FIXME: what is outsideCubeMesh?
				Graphics.DrawMesh(outsideCubeMesh, cam.transform.position, Quaternion.identity, blurMaterial, 1, cam, 0);
				cam.Render();
				EndCubeFaceRender(dest, (CubemapFace)i, mip, cam, false);
			}
		}

		// upload final version
		dest.Apply(false);

	}

	void BeginCubeFaceRender(Cubemap target, CubemapFace f, int mipLevel, Camera cam)
	{
		// create temp texture, assign it to camera
		// figure out the size
		int size = target.width >> mipLevel;
		cam.targetTexture = RenderTexture.GetTemporary(size,size,16);

		// configure fov
		//cam.fieldOfView = 90;
		float edgeScale = 0.5f; // adjust this for your GPU
		cam.fieldOfView = 90+90f / (float)size*edgeScale;

		// point camera in right direction
		Matrix4x4 viewMat = SetOrthoNormalBasicInverse(kCubemapOrthoBases[(int)f*3+0], kCubemapOrthoBases[(int)f*3+1],kCubemapOrthoBases[(int)f*3+2]);
		Matrix4x4 translateMat = Matrix4x4.TRS (-cam.transform.position, Quaternion.identity, Vector3.one);
		cam.worldToCameraMatrix = viewMat*translateMat;
	}

	void EndCubeFaceRender(Cubemap target, CubemapFace f, int mipLevel, Camera cam, bool aa)
	{
		// read pixels into destination
		int size = target.width >> mipLevel;
		Texture2D tempTex = new Texture2D (size, size);
		tempTex.ReadPixels(new Rect(0,0,size,size), 0,0, false);
		//Debug.Log (mipLevel);
		target.SetPixels(tempTex.GetPixels(), f, mipLevel);
		Object.DestroyImmediate(tempTex);

		// cleanup camera
		RenderTexture.ReleaseTemporary(cam.targetTexture);
		cam.targetTexture = null;
		cam.ResetWorldToCameraMatrix();
	}

	Matrix4x4 SetOrthoNormalBasicInverse (Vector3 inX, Vector3 inY, Vector3 inZ)
	{
		Matrix4x4 mat = Matrix4x4.identity;
		mat [0, 0] = inX[0];	mat [1, 0] = inY[0];	mat [2, 0] = inZ[0];	mat [3, 0] = 0;
		mat [0, 1] = inX[1];	mat [1, 1] = inY[1];	mat [2, 1] = inZ[1];	mat [3, 1] = 0;
		mat [0, 2] = inX[2];	mat [1, 2] = inY[2];	mat [2, 2] = inZ[2];	mat [3, 2] = 0;
		mat [0, 3] = 0;		mat [1, 3] = 0;		mat [2, 3] = 0;		mat [3, 3] = 1;
		return mat;
	}
}