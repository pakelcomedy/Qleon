package com.pakelcomedy.qleon.ui.auth

import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.database.FirebaseDatabase
import com.pakelcomedy.qleon.R
import com.pakelcomedy.qleon.databinding.FragmentLoginBinding
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import androidx.activity.result.contract.ActivityResultContracts

class LoginFragment : Fragment(R.layout.fragment_login) {

    private var _binding: FragmentLoginBinding? = null
    private val binding get() = _binding!!

    private lateinit var googleSignInClient: GoogleSignInClient
    private lateinit var firebaseAuth: FirebaseAuth

    companion object {
        private const val TAG = "LoginFragment"
    }

    // Activity Result Callback untuk Google Sign-In
    private val signInResult =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            if (result.resultCode == android.app.Activity.RESULT_OK) {
                val task = GoogleSignIn.getSignedInAccountFromIntent(result.data)
                try {
                    val account = task.getResult(Exception::class.java)
                    if (account != null) {
                        firebaseAuthWithGoogle(account)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Google Sign-In failed", e)
                    Toast.makeText(requireContext(), "Login Failed: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            }
        }

    override fun onViewCreated(view: android.view.View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        _binding = FragmentLoginBinding.bind(view)

        // Inisialisasi FirebaseAuth
        firebaseAuth = FirebaseAuth.getInstance()

        // Jika user sudah login, langsung navigasi ke Home
        if (firebaseAuth.currentUser != null) {
            navigateToHome()
        } else {
            setupGoogleSignIn()
        }

        // Listener untuk tombol Google Login
        binding.googleLoginButton.setOnClickListener {
            signInWithGoogle()
        }
    }

    private fun setupGoogleSignIn() {
        val googleSignInOptions = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(getString(R.string.default_web_client_id)) // Pastikan ada di strings.xml
            .requestEmail()
            .build()

        googleSignInClient = GoogleSignIn.getClient(requireContext(), googleSignInOptions)
    }

    private fun signInWithGoogle() {
        val signInIntent = googleSignInClient.signInIntent
        signInResult.launch(signInIntent)
    }

    private fun firebaseAuthWithGoogle(account: GoogleSignInAccount) {
        val credential = GoogleAuthProvider.getCredential(account.idToken, null)
        lifecycleScope.launch {
            try {
                val authResult = firebaseAuth.signInWithCredential(credential).await()
                val user = authResult.user
                if (user != null) {
                    saveUsernameToDatabase(user.uid, account.displayName)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Firebase Auth with Google failed", e)
                Toast.makeText(requireContext(), "Authentication Failed", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun saveUsernameToDatabase(userId: String, displayName: String?) {
        // Hanya menyisakan huruf dan angka
        val filteredName = displayName?.replace(Regex("[^a-zA-Z0-9]"), "") ?: ""

        // Jika nama setelah filter kosong, gunakan nama default
        val username = if (filteredName.isNotEmpty()) {
            filteredName.lowercase()
        } else {
            "user_$userId"
        }

        Log.d(TAG, "Username to be saved: $username")

        val database = FirebaseDatabase.getInstance()
        val userRef = database.reference.child("users").child(userId)

        userRef.child("username").setValue(username).addOnCompleteListener { task ->
            if (task.isSuccessful) {
                Log.d(TAG, "Username saved successfully: $username")
                navigateToHome()
            } else {
                Log.e(TAG, "Failed to save username: ${task.exception?.message}")
                Toast.makeText(requireContext(), "Failed to save username. Please try again.", Toast.LENGTH_SHORT).show()
            }
        }.addOnFailureListener { e ->
            Log.e(TAG, "Database error: ${e.message}")
            Toast.makeText(requireContext(), "Database Error: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }

    private fun navigateToHome() {
        val action = LoginFragmentDirections.actionLoginFragmentToHomeFragment()
        findNavController().navigate(action)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
