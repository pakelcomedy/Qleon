package com.pakelcomedy.qleon.ui.newchat

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.navigation.fragment.findNavController
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.FirebaseDatabase
import com.pakelcomedy.qleon.R
import com.pakelcomedy.qleon.databinding.FragmentNewChatBinding

class NewChatFragment : Fragment(R.layout.fragment_new_chat) {

    private var _binding: FragmentNewChatBinding? = null
    private val binding get() = _binding!!

    private val viewModel: NewChatViewModel by viewModels()

    // Firebase Database reference
    private val database = FirebaseDatabase.getInstance()
    private val usersRef = database.reference.child("users")

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentNewChatBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Check if user is authenticated
        val currentUser = FirebaseAuth.getInstance().currentUser
        if (currentUser == null) {
            Log.e("Auth", "No user is logged in!")
            Toast.makeText(requireContext(), "Please log in first.", Toast.LENGTH_SHORT).show()
            findNavController().navigateUp()
            return
        }

        Log.d("Auth", "User is logged in: ${currentUser.uid}")

        // Observe ViewModel messages
        viewModel.message.observe(viewLifecycleOwner) { message ->
            message?.let {
                Toast.makeText(requireContext(), it, Toast.LENGTH_SHORT).show()
            }
        }

        // Set click listener for the "Connect" button
        binding.connectButton.setOnClickListener {
            val usernameInput = binding.ETusername.text.toString().trim()
            if (validateUsername(usernameInput)) {
                checkUsernameInDatabase(usernameInput)
            }
        }
    }

    private fun validateUsername(username: String): Boolean {
        return when {
            username.isEmpty() -> {
                Toast.makeText(requireContext(), "Please enter a username", Toast.LENGTH_SHORT).show()
                false
            }
            username.length < 3 -> {
                Toast.makeText(requireContext(), "Username must be at least 3 characters long", Toast.LENGTH_SHORT).show()
                false
            }
            !username.matches(Regex("^[a-zA-Z0-9_]+$")) -> {
                Toast.makeText(requireContext(), "Username can only contain letters, numbers, and underscores", Toast.LENGTH_SHORT).show()
                false
            }
            else -> true
        }
    }

    private fun checkUsernameInDatabase(username: String) {
        usersRef.orderByChild("username").equalTo(username).get()
            .addOnSuccessListener { snapshot ->
                if (snapshot.exists()) {
                    val contactName = snapshot.children.firstOrNull()?.key // Mengambil UID
                    if (contactName != null) {
                        val action = NewChatFragmentDirections
                            .actionNewChatFragmentToChatFragment(
                                username = username,
                                contactName = contactName
                            )
                        findNavController().navigate(action)
                    } else {
                        Toast.makeText(requireContext(), "Error: No contact name!", Toast.LENGTH_SHORT).show()
                    }
                } else {
                    Toast.makeText(requireContext(), "Username not found!", Toast.LENGTH_SHORT).show()
                }
            }
            .addOnFailureListener { e ->
                Toast.makeText(requireContext(), "Database error: ${e.message}", Toast.LENGTH_SHORT).show()
                Log.e("DatabaseError", "Error checking username: ${e.message}")
            }
    }

    private fun navigateToChat(username: String, contactName: String, userId: String) {
        val action = NewChatFragmentDirections.actionNewChatFragmentToChatFragment(
            username = username,
            contactName = contactName
        )
        Log.d("Navigation", "Navigating to ChatFragment with username: $username and userId: $userId")
        findNavController().navigate(action)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}