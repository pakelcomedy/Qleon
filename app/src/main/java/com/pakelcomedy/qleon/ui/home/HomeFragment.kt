package com.pakelcomedy.qleon.ui.home

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.navigation.fragment.findNavController
import com.pakelcomedy.qleon.R
import com.pakelcomedy.qleon.databinding.FragmentHomeBinding

class HomeFragment : Fragment(R.layout.fragment_home) {

    private var _binding: FragmentHomeBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentHomeBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Debugging NavController current destination (can be removed once issues are resolved)
        val currentDestination = findNavController().currentDestination?.id
        Log.d("NavigationDebug", "Current Destination: $currentDestination")

        // Button click listeners for navigation
        binding.chatsButton.setOnClickListener {
            // Navigate to Home Chat
            findNavController().navigate(R.id.action_homeFragment_to_homeChatFragment)
        }

        binding.newChatButton.setOnClickListener {
            // Navigate to New Chat Fragment
            findNavController().navigate(R.id.action_homeFragment_to_newChatFragment)
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
