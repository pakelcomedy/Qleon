package com.pakelcomedy.qleon.ui.newchat

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Observer
import androidx.navigation.fragment.findNavController
import com.pakelcomedy.qleon.R
import com.pakelcomedy.qleon.databinding.FragmentNewChatBinding

class NewChatFragment : Fragment(R.layout.fragment_new_chat) {

    private var _binding: FragmentNewChatBinding? = null
    private val binding get() = _binding!!

    // Inisialisasi ViewModel
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

        // Observe LiveData untuk pesan
        viewModel.message.observe(viewLifecycleOwner, Observer { message ->
            message?.let {
                Toast.makeText(requireContext(), it, Toast.LENGTH_SHORT).show()
            }
        })

        // Set click listener untuk tombol "Connect"
        binding.connectButton.setOnClickListener {
            val usernameInput = binding.ETusername.text.toString().trim()
            if (usernameInput.isNotEmpty()) {
                // Create the bundle to pass the username
                val bundle = Bundle().apply {
                    putString("username", usernameInput) // Pass 'username'
                }
                // Ensure you're navigating from the correct fragment (NewChatFragment)
                findNavController().navigate(R.id.action_newChatFragment_to_chatFragment, bundle)
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
