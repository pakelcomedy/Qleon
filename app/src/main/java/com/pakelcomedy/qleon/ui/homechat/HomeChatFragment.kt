package com.pakelcomedy.qleon.ui.homechat

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import androidx.recyclerview.widget.LinearLayoutManager
import com.pakelcomedy.qleon.R
import com.pakelcomedy.qleon.adapter.ContactAdapter
import com.pakelcomedy.qleon.databinding.FragmentHomeChatBinding
import kotlinx.coroutines.launch

class HomeChatFragment : Fragment(R.layout.fragment_home_chat) {

    private var _binding: FragmentHomeChatBinding? = null
    private val binding get() = _binding!!

    private val viewModel: HomeChatViewModel by viewModels()

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentHomeChatBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Setup RecyclerView
        val adapter = ContactAdapter(emptyList()) { contact ->
            viewModel.onContactSelected(contact)  // Handle contact click
        }
        binding.chatList.layoutManager = LinearLayoutManager(requireContext())
        binding.chatList.adapter = adapter

        // Observe contact list from ViewModel
        viewModel.recentContacts.observe(viewLifecycleOwner) { contactList ->
            adapter.updateContacts(contactList)  // Update the adapter with the contact list
        }

        // Observe navigation events from ViewModel
        lifecycleScope.launch {
            viewModel.navigationEvent.collect { contactName ->
                navigateToChatFragment(contactName)  // Navigate when an event is collected
            }
        }
    }

    private fun navigateToChatFragment(contactName: String) {
        // Use the generated direction class to navigate
        findNavController().navigate(R.id.action_homeFragment_to_chatFragment)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}