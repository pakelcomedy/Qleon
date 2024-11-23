package com.pakelcomedy.qleon.ui.chat

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Observer
import androidx.recyclerview.widget.LinearLayoutManager
import com.pakelcomedy.qleon.R
import com.pakelcomedy.qleon.adapter.MessageAdapter
import com.pakelcomedy.qleon.databinding.FragmentChatBinding

class ChatFragment : Fragment(R.layout.fragment_chat) {

    private var _binding: FragmentChatBinding? = null
    private val binding get() = _binding!!

    private val viewModel: ChatViewModel by viewModels()
    private lateinit var messageAdapter: MessageAdapter

    // Optionally, define the contact name if passed from the previous fragment
    private var contactName: String? = null

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentChatBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Retrieve arguments passed from the previous fragment (e.g., contact name)
        contactName = arguments?.getString("username") // Adjust based on your argument key

        // Optionally set the contact name in the UI
        contactName?.let {
            binding.contactName.text = it // Ensure this TextView is in your layout
        }

        // Initialize RecyclerView and MessageAdapter
        messageAdapter = MessageAdapter()
        binding.messageList.apply {
            layoutManager = LinearLayoutManager(requireContext())
            adapter = messageAdapter
        }

        // Observe messages from the ViewModel
        viewModel.messages.observe(viewLifecycleOwner, Observer { messages ->
            messages?.let {
                messageAdapter.submitList(it)
                binding.messageList.scrollToPosition(it.size - 1) // Auto-scroll to the latest message
            }
        })

        // Handle send button click
        binding.sendButton.setOnClickListener {
            val messageText = binding.messageInput.text.toString()
            if (messageText.isNotBlank()) {
                // Send message via ViewModel
                viewModel.sendMessage(messageText)
                binding.messageInput.text.clear() // Clear the input after sending
            } else {
                Toast.makeText(requireContext(), "Message cannot be empty", Toast.LENGTH_SHORT).show()
            }
        }

        // (Optional) Simulate a reply after a delay for testing purposes
        simulateReply()
    }

    // Simulate a reply from the contact
    private fun simulateReply() {
        // This would be handled through ViewModel in a real case (e.g., Firebase)
        viewModel.receiveMessage("This is an auto-reply!") // Simulate reply
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}