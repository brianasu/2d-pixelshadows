using UnityEngine;
using System.Collections;

public class Move : MonoBehaviour
{
	private void Update ()
	{
		Vector3 velocity = Vector3.zero;
		
		float horz = Input.GetAxis ("Horizontal");
		velocity = Vector3.right * horz;
		
		
		Vector3 prevPosHorz = transform.position;
		transform.Translate (velocity * Time.deltaTime * 5, Space.World); 
		
		// do sliding collision here
		
		
		float vert = Input.GetAxis ("Vertical");
		velocity = Vector3.up * vert;
		
		Vector3 prevPosVert = transform.position;
		transform.Translate (velocity * Time.deltaTime * 5, Space.World); 
		
		// do sliding collision here
	}
}
