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
import com.pakelcomedy.qleon.R
import com.pakelcomedy.qleon.databinding.FragmentNewChatBinding

class NewChatFragment : Fragment(R.layout.fragment_new_chat) {

    private var _binding: FragmentNewChatBinding? = null
    private val binding get() = _binding!!

    private val viewModel: NewChatViewModel by viewModels()

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentNewChatBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Observe LiveData for messages
        viewModel.message.observe(viewLifecycleOwner) { message ->
            message?.let {
                Toast.makeText(requireContext(), it, Toast.LENGTH_SHORT).show()
            }
        }

        // Set click listener for "Connect" button
        binding.connectButton.setOnClickListener {
            val usernameInput = binding.ETusername.text.toString().trim()
            if (usernameInput.isNotEmpty()) {
                try {
                    // Ensure action is correct and Safe Args is generated
                    val action = NewChatFragmentDirections
                        .actionNewChatFragmentToChatFragment(
                            username = usernameInput,
                            contactName = "some_contact_name" // Replace with actual contact name logic
                        )
                    Log.d("Navigation", "Navigating to ChatFragment with username: $usernameInput")
                    findNavController().navigate(action)
                } catch (e: IllegalArgumentException) {
                    Log.e("NavigationError", "Navigation action not found: ${e.message}")
                }
            } else {
                Toast.makeText(requireContext(), "Please enter a username", Toast.LENGTH_SHORT).show()
            }
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}